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
# On Solaris 8 and greater required information can be gathered from 
# the corefile itself, but on earlier versions of Solaris access is
# required to a running instance of the application
#
# Some of the referenced libraries can be accessed via more than one link/path
# the path/link used but this script may differ from the one that dbx will want
# to use locally, especially if the libraries are found using an executable versus
# the corefile or PID, adding the additional links when unpacking the data may be required
#
# When checking for previous output files it only checks for gzipped versions
#
# pmap will automaticly search the path for the corefile's executable if it 
# does not find the executable in the location where it expects it to be. This
# check appears to be by name ONLY so there is a chance that if the name is 'common'
# and the script is run on a different system that you may get the wrong executable
#
#
# Note when Editing
#
# Please place more static and system wide information into the ${UNIQUEBASE}/extras directory
# and more dynamic and corefile related information into the ${UNIQUEBASE}/info directory
# this will allow multiple core files to be processed and only the  casenumber_corefile.tar.*
# file to be sent to sun as the libraries and executeable are not likely to change between 
# two crashes, etc..
#
# Variables used within the script
#
# $SOLARISVERSION integer which is the solaris version (or the number after the decimal point in uname -r )
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
#
#
#####
UNIQUEBASE=`/usr/bin/date +"/tmp/%Y-%B-%e-%H-%M-%S-$$" | sed -e 's/ //g'`
release=`/bin/uname -r`
PATH=/usr/bin:/usr/proc/bin:$PATH

if /usr/bin/test \( $# -lt 2 \) -o \( $# -gt 3 \)
  then
	/bin/echo
	/bin/echo "Usage: $0 <case# or OutputFilename> <Corefile> [PID of process | Path to Executable]"
	/bin/echo
	/bin/echo "Note: PID or Executable is ignore on Solaris 8 or greater but"
	/bin/echo "      required for Solaris 7 and earlier versions of Solaris"
	/bin/echo
	exit 1;
fi

# Check Sun OS major version only know how to work within version 5.x
if /usr/bin/test  \( `/bin/echo $release | /bin/cut -d. -f1` -ne 5 \)
   then
	/bin/echo "What version of Solaris/Sun OS are you using?"
	/bin/uname -a
fi

SOLARISVERSION=`/bin/echo $release | /bin/cut -d. -f2 `

# Check Sun OS minor version 
if /usr/bin/test \(  $SOLARISVERSION  -lt 8 \) 
  then
	if /usr/bin/test \( $# -lt 3 \)
  	  then
	/bin/echo "[PID] or Executable is required for OS versions before Solaris 8"
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

/bin/ls /usr/lib/ld.so.* /usr/lib/*_db.so.* > ${UNIQUEBASE}/request.list
/bin/ls /lib/ld.so.* /lib/*_db.so.* >> ${UNIQUEBASE}/request.list

if /usr/bin/uname -p | grep 'sparc' 2>&1 >/dev/null
  then
	/bin/ls /usr/lib/sparcv9/ld.so.* /usr/lib/sparcv9/*_db.so.* \
		>> ${UNIQUEBASE}/request.list
fi

# Grab the debug thread library for the Alternative thread library 
# on Solaris 8, if Solaris 8
if /usr/bin/test \(  $SOLARISVERSION -eq 8 \)
  then
	ls /usr/lib/lwp/*_db.so.*  >> ${UNIQUEBASE}/request.list

	if /usr/bin/uname -p | grep 'sparc' 2>&1 >/dev/null
  	  then
		ls /usr/lib/lwp/sparcv9/*_db.so.*  >> ${UNIQUEBASE}/request.list
	fi
fi

# Gather libraries used by the Application that created the corefile
# on Solaris 8 and greater this information is taken from the corefile
# on Solaris 7 and earlier it can be taken from a copy of the running
# process or by referencing the executable itself (running process is better)

if /usr/bin/test \(  $SOLARISVERSION -lt 8 \)
  then
	# check if the Argument is a process
	if /usr/bin/test $THIRDARG == "PID"
	   then
		/bin/echo "Using PID of $3 for Libraries"
		pldd $3 | /usr/bin/tail +2  >> ${UNIQUEBASE}/request.list
	   else
		/bin/echo "Using ldd of $3 for Libraries"
		/usr/bin/ldd $3 | /usr/bin/grep '=>' | /usr/bin/cut -d\> -f2 | \
			/usr/bin/awk '{ print $1 }' >>  ${UNIQUEBASE}/request.list
 		/usr/bin/ldd $3 | /usr/bin/grep -v find | /usr/bin/grep -v '=>' | \
			/usr/bin/awk '{ print $1 }' >> ${UNIQUEBASE}/request.list
		THIRDARG="EXE"
	fi
  else
	pldd $COREFILE | /usr/bin/tail +2 >>  ${UNIQUEBASE}/request.list
fi


# Find the Executable either from the corefile for Solaris 8
# or newer versions of Solaris otherwise use PID or Executable itself

if /usr/bin/test \( $SOLARISVERSION  -ge 8 \)
  then

# use pmap to get the path of the executable file being executed.  On sparc this is easy as the first 
# file mapped into the address space is the executable but on x86 the executable is mapped in between
# the stack and heap (or so it seems)
	if /usr/bin/uname -p | grep 'sparc' 2>&1 >/dev/null
	  then
		EXEFILE=`pmap $COREFILE | /usr/bin/head -2 | /usr/bin/tail -1 | /usr/bin/awk '{ print $4 }'`
	  else
		BOTTOMLINE=`pmap $COREFILE | grep -n '\[ heap \]' | cut -d: -f1`
		BOTTOMLINE=`echo "${BOTTOMLINE} - 1" | bc `
		TOPLINE=`pmap $COREFILE | grep -n '\[ stack \]' | cut -d: -f1`
		TOPLINE=`echo "${BOTTOMLINE} - ${TOPLINE}" | bc `
		EXEFILE=`pmap $COREFILE | /usr/bin/head -${BOTTOMLINE} | /usr/bin/tail -${TOPLINE} | /usr/bin/awk '{ print $4 }'`
		EXEFILE=`echo ${EXEFILE} | xargs -n 1 | uniq`
		if /usr/bin/test \( `/bin/echo ${EXEFILE} | wc -w ` -ne 1 \)
		  then
			/bin/echo "problem finding executable... please report\n"
			/usr/bin/uname -p
			/bin/echo "pmap corefile \| head -${BOTTOMLINE} \| tail -${TOPLINE}"
			pmap $COREFILE | /usr/bin/head -${BOTTOMLINE} | /usr/bin/tail -${TOPLINE}
			exit 1
		fi
	fi
  else 

	if /usr/bin/test $THIRDARG == "PID"
	   then
		/bin/echo "Using PID of $3 to find executable"

		# Following the same process as under using pmap for corefile

		if /usr/bin/uname -p | grep 'sparc' 2>&1 >/dev/null
	  	  then
			EXEFILE=`pmap $3 | /usr/bin/head -2 | /usr/bin/tail -1 | /usr/bin/awk '{ print $4 }'`
	  	  else 
			BOTTOMLINE=`pmap $3 | grep -n '\[ heap \]' | cut -d: -f1`
			BOTTOMLINE=`echo "${BOTTOMLINE} - 1" | bc `
			TOPLINE=`pmap $3 | grep -n '\[ stack \]' | cut -d: -f1`
			TOPLINE=`echo "${BOTTOMLINE} - ${TOPLINE}" | bc `
			EXEFILE=`pmap $3 | /usr/bin/head -${BOTTOMLINE} | /usr/bin/tail -${TOPLINE} | /usr/bin/awk '{ print $4 }'`
			EXEFILE=`echo ${EXEFILE} | xargs -n 1 | uniq`

			if /usr/bin/test \( `/bin/echo ${EXEFILE} | wc -w ` ne 1 \)
			  then
				/bin/echo "problem finding executable... please report\n"
				/usr/bin/uname -p
				/bin/echo "pmap pid | head -${BOTTOMLINE} | tail -${TOPLINE}"
				pmap $3 | /usr/bin/head -${BOTTOMLINE} | /usr/bin/tail -${TOPLINE}
				exit 1
			fi
		fi 
 	  else 
		/bin/echo "Using $3 as the executable"
		if /usr/bin/test \( `/bin/echo $3 | cut -c -1` == "/" \)
		   then
			EXEFILE=$3
		   else
			EXEFILE=`pwd`/$3
		fi
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
		EXEFILE=`/bin/which ${TARGET}`
		if /bin/echo ${EXEFILE} | grep "^no ${TARGET}" 2>&1 >/dev/null
		  then
			/bin/echo "${TARGET} was not found in PATH... searching file systems...\n"
			/bin/echo "This may take some time (possibly 30+ minutes)\n"
/bin/echo "Warning: Problem locating Executable file... check info/exe-search.txt\n" >> ${UNIQUEBASE}/error.log
EXEFILE=`/bin/find / -type f -name ${TARGET} -print 2>/dev/null | /bin/tee ${UNIQUEBASE}/info/exe-search.txt`
			if /usr/bin/test \( "x${EXEFILE}x" == "xx" \)
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

bcore=`/usr/bin/basename "$COREFILE"`
bexe=`/usr/bin/basename "$EXEFILE"`

SAVEDIR=`/bin/pwd`
cd ${UNIQUEBASE}
/bin/ln -s $COREFILE $bcore
/bin/ln -s $EXEFILE $bexe
/bin/ln -s $bcore corefile
/bin/ln -s $bexe  executable

/bin/mkdir libs ; cd libs

# gather Application libraries and create dbxrc file
for LIBDIR in `cut -c 2- ${UNIQUEBASE}/request.list | 
	 sed -e 's/\/[^/]*$//' | sort -u `
  do 
	if /usr/bin/test \! -d $LIBDIR
	  then  
		/bin/mkdir -p $LIBDIR
	fi
	echo "pathmap /${LIBDIR} \$PWD/libs/$LIBDIR" \
		>> ${UNIQUEBASE}/dbxrc.tmp 
  done

for LIB in `cut -c 2- ${UNIQUEBASE}/request.list`
  do
	( cd `/usr/bin/dirname $LIB` ; ln -s /$LIB `/usr/bin/basename $LIB` )
  done

echo "pathmap /lib \$PWD/libs/usr/lib" >> ${UNIQUEBASE}/dbxrc.tmp
echo "dbxenv core_lo_pathmap on" > ${UNIQUEBASE}/dbxrc
sort -u ../dbxrc.tmp >> ${UNIQUEBASE}/dbxrc
echo "debug executable corefile" >> ${UNIQUEBASE}/dbxrc

# Create opencore script to read corefile when it is unpacked

echo "dbx -s dbxrc" > ${UNIQUEBASE}/opencore
chmod 755 ${UNIQUEBASE}/opencore


#################################################
####                                         ####
####  GATHER INFORMATION ABOUT THE COREFILE  ####
####                                         ####
#################################################

/bin/date >> ${UNIQUEBASE}/error.log

# Additional information Gathered on Solaris 8 
# and newer versions of Solaris
if /usr/bin/test \(  $SOLARISVERSION -ge 8 \)
  then

echo "attempting to get file info from corefile" >>  ${UNIQUEBASE}/error.log
/usr/bin/file $COREFILE > ${UNIQUEBASE}/info/file.txt 2>>${UNIQUEBASE}/error.log

echo "attempting to get pldd" >> ${UNIQUEBASE}/error.log
pldd $COREFILE > ${UNIQUEBASE}/info/pldd.txt 2>>${UNIQUEBASE}/error.log

echo "attempting to get pmap" >> ${UNIQUEBASE}/error.log
pmap $COREFILE > ${UNIQUEBASE}/info/pmap.txt 2>>${UNIQUEBASE}/error.log

echo "attempting to get pstack" >> ${UNIQUEBASE}/error.log
pstack $COREFILE > ${UNIQUEBASE}/info/pstack.txt 2>>${UNIQUEBASE}/error.log

###############################
# Solaris 9+ extras to gather # 
###############################

	if /usr/bin/test \(  $SOLARISVERSION -ge 9 \)
	  then

echo "attempting to get pargs" >> ${UNIQUEBASE}/error.log
pargs $COREFILE > ${UNIQUEBASE}/info/pargs.txt 2>>${UNIQUEBASE}/error.log

	fi

  else

##############################################
# Pre - Solaris 8 data Gathering from system #
##############################################
# If previous to version 8 of Solaris, gather the following

	if /usr/bin/test $THIRDARG == "PID"
	  then
		echo "attempting to get pldd of running process" >>  ${UNIQUEBASE}/error.log
		pldd $3 >> ${UNIQUEBASE}/info/pldd-of-running-process.txt 2>> ${UNIQUEBASE}/error.log
		echo "attempting to get pmap -r of running process" >>  ${UNIQUEBASE}/error.log
		pmap -r $3 >> ${UNIQUEBASE}/info/pmap-r-of-running-process.txt 2>> ${UNIQUEBASE}/error.log
	  else
		echo "attempting to get ldd -v of Executable file" >> ${UNIQUEBASE}/error.log
		/usr/bin/ldd -v $3 >>  ${UNIQUEBASE}/info/ldd-of-executable.txt 2>>  ${UNIQUEBASE}/error.log
	fi	
fi


#################################################
####                                         ####
####   GATHER INFORMATION ABOUT THE SYSTEM   ####
####                                         ####
#################################################

/usr/platform/`/usr/bin/uname -i`/sbin/prtdiag > ${UNIQUEBASE}/extras/prtdiag.txt 2>${UNIQUEBASE}/extras/prtdiag.errors

/usr/bin/showrev -p >  ${UNIQUEBASE}/extras/showrev-p.txt 2>${UNIQUEBASE}/extras/showrev-p.errors

/bin/uname -a > ${UNIQUEBASE}/extras/uname.txt 2>${UNIQUEBASE}/extras/uname.errors

############################################
####                                    ####
####   Create the tar file for upload   ####
####                                    ####
############################################

cd  ${UNIQUEBASE}

# Create the two tar files which hold everything
# using the 'h' option inorder to follow symbolic links 

# Grab the actual physical corefile and info directory
tar cvvhf $SAVEDIR/${CASENUMBER}_corefiles.tar $bcore info

# Grab all the extra files created 
tar rvvf $SAVEDIR/${CASENUMBER}_corefiles.tar dbxrc opencore corefile executable *.log

# Grab physical copies of all the executable & libraries and anything in or linked to from extras directory
tar cvvhf $SAVEDIR/${CASENUMBER}_libraries.tar $bexe libs extras

cd $SAVEDIR

echo Cleaning up
/bin/rm -rf ${UNIQUEBASE}/*
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

