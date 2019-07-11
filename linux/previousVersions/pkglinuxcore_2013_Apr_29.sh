#!/bin/sh
#########
#
# Collect and package libraries used by Application 
# and other libraries needed to read a corefile 
# on a system other than the one that generated it.
#
# Latest Copy should always be located at: 
# /net/bur-home1.east/global/export/home1/43/ra138236/bin/pkgcore.sh
#
# Usage:
#
#   pkgcore {case# or package file} {corefile} [processid|Executable]
#   Note: processid & Executabe will only be used on Solaris 7 and 
#         earlier versions of Solaris, it will be ignored on Solaris 8	
#         and later versions 
#
# Output:
#
#	casenumber_libraries.tar.gz
#	casenumber_corefile.tar.gz
#
# Limitations
#
# Some of the referenced libraries can be accessed via more than one link/path
# the path/link used but this script may differ from the one that gdb will want
# to use locally, especially if the libraries are found using an executable versus
# the corefile or PID, adding the additional links when unpacking the data may be required
#
# When checking for previous output files it only checks for gzipped versions
#
# Note when Editing
#
# Please place more static and system wide information into the ${UNIQUEBASE}/extras directory
# and more dynamic and corefile related information into the ${UNIQUEBASE}/info directory
# this will allow multiple core files to be processed and only the  casenumber_corefile.tar.*
# file to be sent to Versant as the libraries and executeable are not likely to change between 
# two crashes, etc..
#
# Variables used within the script
#
# $LINUXVERSION integer which is the Linux kernel version (or the number after the second  decimal point in uname -r )
# $CASENUMBER used to uniquely package the data and hopefully to keep all the corefile data straight
# $COREFILE absolute path to the corefile being processed
# $EXEFILE absolute path to the executable file 
# $THIRDARG determination if $3 is a PID or Executable ( will be "PID" or "EXE" respectively )
# 
# 
#
#
#
# Change Log
#
# 2005-May-12: initial creation
# 2005-May-16: Finished up work to allow use on Solaris 7 and possibly earlier versions of Solaris
# 2005-May-17: created and saved a simple opencore script to be included in core archive
# 2005-May-26: Fixed bug where script would crash if Case# contained '/' which is not valid within a filename
# 2005-Jul-07: Discovered case where UNIQUEBASE contained a space which broke script
# 2005-Jul-08: Fixed issue, date was space padding output, removed spaces
# 2005-Nov-05: added logic to allow it to function on Solaris X86.  This is not simple because where as on
#		sparc the pmap lists the executable as being the first file mapped into the address space, this
#		is not the case on x86, I am guessing that the executable is always mapped in between the stack
#		and heap and it is the ONLY file mapped into this space, if this  is not true the script will fail
# 2005-Nov-06: Also found a problem if the executable does not exist in the same location it did when the corefile
#		was created and it's not in PATH ... mostly fixed...see limitations
# 2006-Apr-29: Previous to Solaris 10, /lib and /usr/lib were symbolicly linked together, this changed in Solaris 10.
#		Since they are different in Solaris 10 and could possibly be different the script should be altered to 
#		grab any _db libraries from the /lib as well as /usr/lib directory. Fixed by also grabbing debugging
#		libraries from the /lib directory.
# 2008-Aug-28: (Joe Sottile) Converted for RHEL4 from Solaris version so I can debug customer RHEL coredumps!!!!!
#
#
#####
UNIQUEBASE=`/bin/date +"/tmp/%Y-%B-%e-%H-%M-%S-$$" | sed -e 's/ //g'`
release=`/bin/uname -r`
PATH=/usr/bin:$PATH

if /usr/bin/test  \( $# -ne 3 \)
  then
	/bin/echo
	/bin/echo "Usage: $0 <case# or OutputFilename> <Corefile> <PID of process | Path to Executable>"
	/bin/echo
	/bin/echo "Note: PID or Executable is required"
	/bin/echo
	exit 1;
fi

# Check OS major version only know how to work within version 2.6.9 and 2.6.16
if /usr/bin/test  `/bin/echo $release | /bin/cut -d. -f1-2` \!= "2.6" 
   then
	/bin/echo "What version of Linux OS are you using?"
	/bin/uname -a
fi

LINUXVERSION=`/bin/echo $release | /bin/cut -d. -f3 `

	if /usr/bin/test \( $# -lt 3 \)
  	  then
	/bin/echo "[PID] or Executable is required"
	exit 1
	fi
	# Test for type of Third Argument now to avoid duplicate testing later
	if /usr/bin/kill -0 $3 2>/dev/null 
	   then
		/bin/echo "Third argument appears to be a PID = $3"
		THIRDARG="PID"
	   else
		if /usr/bin/test \! -x $3
		  then
			/bin/echo
			/bin/echo "Third argument does not seem to be a PID or Executable"
			/bin/echo "Please check $3 and try again"
			/bin/echo
			exit 1;
		  else
			if /usr/bin/file $3 | grep 'ELF.*-bit.*executable' 2>&1 >/dev/null
			  then
				/bin/echo "Third argument appears to be Executable = $3"
				THIRDARG="EXE"
			  else
				/bin/echo
				/bin/echo "Is $3 a link or start script? Please check!"
				/bin/echo "Binary Executable needed as argument"
				/bin/echo
				exit 1;
			fi
		fi
	fi

# Need to check for and sanitize the CASENUMBER to ensure that there are no characters which would cause problems 
# being in a filename NEED to check for the following characters and change them as follows
#  '/' => '-' 

if /bin/echo $1 | /bin/grep "[/]" 2>&1 >/dev/null
  then
	echo
	echo "CASENUMBER contains characters which are not valid within a filename ... fixing"
	echo "Changing \"$1\" "
	CASENUMBER=`echo $1 | sed -e "s|/|-|g" `
	echo "to \"$CASENUMBER\" "
  else
	CASENUMBER=$1
fi

# Checking for existence of output files
if /usr/bin/test \( -s "${CASENUMBER}_libraries.tar.gz" \) -o \
		\( -s "${CASENUMBER}_corefile.tar.gz" \)
  then
	/bin/echo
	/bin/echo "${CASENUMBER}_libraries.tar.gz or ${CASENUMBER}_corefile.tar.gz"
	/bin/echo "exists in the current directory, please remove or rename and try again."
	/bin/echo
	exit 1
fi

# verify that corefile exists and is readable
if /usr/bin/test `echo $2 | cut -c -1` = "/" 
  then
	COREFILE=$2
  else
	COREFILE=`pwd`/$2
fi

if /usr/bin/test \! \( -f $COREFILE  -a  -r $COREFILE \)
  then
	/bin/echo
	/bin/echo "${COREFILE} is not readable, please check filename and permissions"
	/bin/echo "and try again..."
	/bin/ls -ald ${COREFILE}
	/bin/echo
	exit 1
fi

/bin/echo
/bin/echo "Using corefile: $COREFILE "
/bin/echo

/bin/echo "Creating temporary work directory: ${UNIQUEBASE}"
/bin/mkdir ${UNIQUEBASE}
/bin/mkdir ${UNIQUEBASE}/info
/bin/mkdir ${UNIQUEBASE}/extras

if /usr/bin/test \! \( -d "${UNIQUEBASE}" -a -w "${UNIQUEBASE}" \)
   then
	/bin/echo
	/bin/echo "Problem creating my work directory, please check/fix..."
	/bin/ls -ald ${UNIQUEBASE}
	/bin/echo
	exit 1
fi

##########################################
####                                  ####
#### Build list of libraries which    ####
#### will be collected with core file ####
####                                  ####
##########################################

# Creating library request list

/bin/ls -1 /lib/ld-linux.so.* /etc/ld.so.cache /etc/ld.so.preload /lib/*_db.so.* 2>&1 | grep -v "No such file or directory" > ${UNIQUEBASE}/request.list

# Gather libraries used by the Application that created the corefile
# On all Linux it can be taken from a copy of the running
# process or by referencing the executable itself (running process is better)

	# check if the Argument is a process
	if /usr/bin/test $THIRDARG = "PID"
	   then
		/bin/echo "Using PID of $3 for Libraries"
		/usr/bin/ldd /proc/$3/exe | /bin/grep '=>' | /bin/cut -d\> -f2 | \
			/bin/awk '{ print $1 }' >>  ${UNIQUEBASE}/request.list
 		/usr/bin/ldd /proc/$3/exe | /bin/grep -v find | /bin/grep -v '=>' | \
			/bin/awk '{ print $1 }' >> ${UNIQUEBASE}/request.list
	   else
		/bin/echo "Using ldd of $3 for Libraries"
		/usr/bin/ldd $3 | /bin/grep '=>' | /bin/cut -d\> -f2 | \
			/bin/awk '{ print $1 }' >>  ${UNIQUEBASE}/request.list
 		/usr/bin/ldd $3 | /bin/grep -v find | /bin/grep -v '=>' | \
			/bin/awk '{ print $1 }' >> ${UNIQUEBASE}/request.list
		THIRDARG="EXE"
	fi


# Find the Executable either from the corefile for Solaris 8
# or newer versions of Solaris otherwise use PID or Executable itself

	if /usr/bin/test $THIRDARG = "PID"
	   then
		/bin/echo "Using PID of $3 to find executable"

		EXEFILE=`/bin/ls -la /proc/$3/exe | /bin/cut -d\> -f2`
 	  else 
		/bin/echo "Using $3 as the executable"
		if /usr/bin/test \( `/bin/echo $3 | /bin/cut -c -1` = "/" \)
		   then
			EXEFILE=$3
		   else
			EXEFILE=`pwd`/$3
		fi
	fi




if /usr/bin/test \! -x "$EXEFILE"
  then
	/bin/echo "Problem with determined executable:\"${EXEFILE}\" checking details\n\n"
	if /usr/bin/test \! -e "$EXEFILE"
	  then
		/bin/echo "Warning: executable file could not be found via normal processing"
		/bin/echo "will search PATH then file systems looking for it...\n"
		/bin/echo "If this is NOT the same system that generated the corefile Control-C now"
		/bin/sleep 5
		TARGET=`file ${COREFILE}  | cut -d\' -f2`
		/bin/echo "\n\nSearching for executable with name of \"$TARGET\"\n"
		EXEFILE=`/usr/bin/which ${TARGET}`
		if /bin/echo ${EXEFILE} | grep "^no ${TARGET}" 2>&1 >/dev/null
		  then
			/bin/echo "${TARGET} was not found in PATH... searching file systems...\n"
			/bin/echo "This may take some time (possibly 30+ minutes)\n"
/bin/echo "Warning: Problem locating Executable file... check info/exe-search.txt\n" >> ${UNIQUEBASE}/error.log
EXEFILE=`/bin/find / -type f -name ${TARGET} -print 2>/dev/null | /bin/tee ${UNIQUEBASE}/info/exe-search.txt`
			if /usr/bin/test \( "x${EXEFILE}x" = "xx" \)
			  then
				/bin/echo "Warning....FAILURE... could not locate ${TARGET}\n"
				/bin/echo "Aborting.....\n"
				exit 1;
			  else
				/bin/echo "Found following executable(s)\n"
				/bin/cat ${UNIQUEBASE}/info/exe-search.txt
				/bin/echo "\n\nGuessing and Using First one\n"
				EXEFILE=`echo ${EXEFILE} | xargs -n 1 | head -1`
			fi
		fi

	  else
		/bin/echo "File exists so using it....\n"
	fi
fi


/bin/echo
/bin/echo "Found executable file: $EXEFILE"
/bin/echo

bcore=`/bin/basename "$COREFILE"`
bexe=`/bin/basename "$EXEFILE"`

SAVEDIR=`/bin/pwd`
cd ${UNIQUEBASE}
/bin/ln -s $COREFILE $bcore
/bin/ln -s $EXEFILE $bexe
/bin/ln -s $bcore corefile
/bin/ln -s $bexe  executable

# Use gdb to generate the complete list of libraries loaded into the corefile
/bin/echo "quit" >cmdfile
/usr/local/bin/gdb -c corefile -e executable -x cmdfile 2>&1 \
        | grep "\.so" \
        | sed 's/\.\.\.done//g' \
        | sed 's/\.\.\.//g' \
        | sed 's/Loaded symbols for //g' \
        | sed 's/Reading symbols from //g' \
        | sed 's/Symbol file not found for //g' \
        | sed 's/(no debugging symbols found)\.//g' \
        | sed 's/warning: .dynamic section for \"//g' \
        | sed 's/\" is not at the expected address//g' \
        | sed 's/: No such file or directory.//g' \
        | sed 's/ (wrong library or version mismatch?)//g' \
        | sort -u \
        >> request.list
mv -f request.list request.tmp
sort -u request.tmp >request.list
rm -f request.tmp cmdfile

/bin/mkdir libs ; cd libs

# gather Application libraries and create dbxrc file
/bin/echo "set solib-absolute-path ./libs" >${UNIQUEBASE}/.gdbinit

for LIB in `cut -c 2- ${UNIQUEBASE}/request.list`
  do
	( mkdir -p `/usr/bin/dirname $LIB` ; cd `/usr/bin/dirname $LIB` ; ln -s /$LIB `/bin/basename $LIB` )
  done

# Create opencore script to read corefile when it is unpacked
echo "gdb -c corefile -e executable" > ${UNIQUEBASE}/opencore
chmod 755 ${UNIQUEBASE}/opencore


#################################################
####                                         ####
####  GATHER INFORMATION ABOUT THE COREFILE  ####
####                                         ####
#################################################

/bin/date >> ${UNIQUEBASE}/error.log

echo "attempting to get file info from corefile" >>  ${UNIQUEBASE}/error.log
/usr/bin/file $COREFILE > ${UNIQUEBASE}/info/file.txt 2>>${UNIQUEBASE}/error.log

#################################################
####                                         ####
####   GATHER INFORMATION ABOUT THE SYSTEM   ####
####                                         ####
#################################################

/bin/uname -a > ${UNIQUEBASE}/extras/uname.txt 2>${UNIQUEBASE}/extras/uname.errors

############################################
####                                    ####
####   Create the tar file for upload   ####
####                                    ####
############################################

cd  ${UNIQUEBASE}

# Create the two tar files which hold everything
# using the 'h' option inorder to follow symbolic links 

# Grab the actual physical corefile 
tar cvvhf $SAVEDIR/${CASENUMBER}_corefiles.tar $bcore 

# Grab physical copies of all the executable & libraries and anything in or linked to from extras directory
tar cvvhf $SAVEDIR/${CASENUMBER}_libraries.tar $bexe libs extras 

# Grab all the extra files created 
tar rvvf $SAVEDIR/${CASENUMBER}_libraries.tar .gdbinit opencore corefile executable *.log info

cd $SAVEDIR

echo Cleaning up
/bin/rm -rf ${UNIQUEBASE}/* ${UNIQUEBASE}/.gdbinit
/bin/rmdir  ${UNIQUEBASE}

# compress the output files
/bin/echo Compressing the output files
/bin/ls -l ${CASENUMBER}_*
if /usr/bin/test -x /usr/bin/gzip 
  then
	/usr/bin/gzip -9 ${CASENUMBER}_*
  else
	/usr/bin/compress ${CASENUMBER}_*
fi
/bin/echo
/bin/echo Please Send the following two files to Sun
/bin/ls -l ${CASENUMBER}_*

