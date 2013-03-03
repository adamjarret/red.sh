#!/bin/bash

################################################################################
################################################################################
######
######   red.sh
######   --- 
######   Adam Jarret
######   http://atj.me
######   adam@atj.me
######
######   Last Update: Mar 2, 2013
######

# Text color variables
bldblk=$(tput bold)             # Bold Black
bldred=${bldblk}$(tput setaf 1) # Bold Red
txtund=$(tput sgr 0 1)          # Underline
txtrst=$(tput sgr0)             # Reset

# Display usage if no parameters given
if [[ -z "$@" ]]; then
  echo -e "\n$bldblk  Usage:$txtrst"
  echo -e "\n$bldred    red.sh$txtrst [options] [parameters] local/file/path.txt"
  echo -e "\n$bldblk  Options:$txtrst\n"
  echo -e "    -c \t Create specified files that do not exist"
  echo -e "    -f \t Create specified files and their parent folders that do not exist"
  echo -e "    -q \t Quiet (keep terminal output to a minimum)"
  echo -e "    -t \t Test (command will be generated but not executed)"
  echo -e "\n$bldblk  Parameters:$txtrst\n"
  echo -e "    -a \t App to launch {BBEdit.app or TextWrangler.app, default: BBEdit.app}"
  echo -e "    -h \t Mac IP (where the App is) {default: detect via SSH session}"
  echo -e "    -p \t Mac SSH Port {default: 22}"
  echo -e "    -u \t Mac User {default: root}"
  echo -e "    -H \t Server IP (where the file is) {default: detect via SSH session}"
  echo -e "    -P \t Server SSH Port {default: detect via SSH session, 22 if not found}"
  echo -e "    -U \t Server User {default: detect via whoami}"
  echo -e "\n$bldblk  Examples:$txtrst"
  echo -e "\n    ${bldred}red.sh${txtrst} -u MacUser /etc/hosts manifest.json conf.d/*.conf"
  echo -e "\n    ${bldred}red.sh${txtrst} -u MacUser -h 192.168.1.7 -p 2222 -a TextWrangler.app test.txt"
  echo -e "\n$bldblk  About:$txtrst"
  echo -e "\n    ${bldred}red.sh${txtrst} uses SSH gymnastics to make it easy to edit files on your Mac \n    that reside on another server. Once red.sh is installed on the server,\n    you can use it in place of pico/vi/emacs to edit files more comfortably.\n\n    Known to work with ${txtund}BBEdit$txtrst and ${txtund}TextWrangler$txtrst but any App that can handle\n    sftp:// URLs should work.\n\n    See ${txtund}https://github.com/adamjarret/red.sh$txtrst for more information."
  echo -e "\n$bldblk  Credits:$txtrst"
  echo -e "\n    Adam Jarret\n    http://atj.me\n    adam@atj.me\n\n"
  exit
fi

# Defaults
L_APP="BBEdit.app"
L_PORT="22"
L_USER="root"
R_PORT="22"
R_USER=`whoami`

# Detect IPs/User if script is currently being run over SSH
if [ ! -z "$SSH_CONNECTION" ]; then
  OIFS=$IFS
  IFS=' ' read -a SSH_DATA <<< "$SSH_CONNECTION"
  L_HOST=${SSH_DATA[0]}
  R_HOST=${SSH_DATA[2]}
  R_PORT=${SSH_DATA[3]}
  IFS=$OIFS
fi

# Parse option params
OPTIND=1
while getopts "a:h:p:u:H:P:U:cfqt" opt; do
  case $opt in
    c)
      CREATE_FILE="yes";;
    f)
      CREATE_FILE="yes"
      CREATE_DIR="yes"
      ;;
    q)
      QUIET="yes";;
    t)
      SIMULATE_ONLY="yes";;
    a)
      L_APP=$OPTARG;;
    h)
      L_HOST=$OPTARG;;
    p)
      L_PORT=$OPTARG;;
    u)
      L_USER=$OPTARG;;
    H)
      R_HOST=$OPTARG;;
    P)
      R_PORT=$OPTARG;;
    U)
      R_USER=$OPTARG;;
    \?)
      exit 1;;
    :)
      exit 1;;
  esac
done

function the_end()
{
  [[ -z "$QUIET" ]] && echo -e "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
  exit
}

# Check that all required information has been detected/specified
if [ -z "$L_HOST" ] || [ -z "$R_HOST" ]; then
  echo " X ERROR: -h and -H options are required when ${bldred}red.sh${txtrst} is not being run over SSH"
  the_end
fi

# Remove options from param list (Thanks http://mywiki.wooledge.org/BashFAQ/035#getopts)
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

# Thanks http://www.linuxjournal.com/content/normalizing-path-names-bash
function normalize_path()
{
    # Remove all /./ sequences.
    local   path=${1//\/.\//\/}
    
    # Remove dir/.. sequences.
    while [[ $path =~ ([^/][^/]*/\.\./) ]]
    do
        path=${path/${BASH_REMATCH[0]}/}
    done
    echo $path
}

# Thanks https://github.com/morgant/realpath
function truepath()
{
	local tf_rel_path="$1"
  local exit_code=0
	
	# make sure the string isn't empty as that implies something in further logic
	if [ -z "$tf_rel_path" ]; then
	  return 1
	else
	
	  # if tf_rel_path is already absolute, echo it normalized
	  if [[ $tf_rel_path == \/* ]]; then
  	  nml_path=$(normalize_path $tf_rel_path)
  	  echo "$nml_path"
  	  if [ -f $nml_path ]; then
    	  return 0
    	elif [ -d `dirname "$nml_path"` ]; then
    	  # File not found
    	  return 3
    	else
    	  # Parent dir not found
    	  return 2
  	  fi
	  fi
	
		# start with the file name (sans the trailing slash)
		tf_rel_path="${tf_rel_path%/}"
		
		# if we stripped off the trailing slash and were left with nothing, that means we're in the root directory
		if [ -z "$tf_rel_path" ]; then
			tf_rel_path="/"
		fi
		
		# get the basename of the file (ignoring '.' & '..', because they're really part of the path)
		local file_basename="${tf_rel_path##*/}"
		if [[ ( "$file_basename" = "." ) || ( "$file_basename" = ".." ) ]]; then
			file_basename=""
		fi
		
		# extracts the directory component of the full path, if it's empty then assume '.' (the current working directory)
		local directory="${tf_rel_path%$file_basename}"
		if [ -z "$directory" ]; then
			directory='.'
		fi
				
		# attempt to change to the directory
		if ! cd "$directory" &>/dev/null ; then
		  # parent folder does not exist error
			exit_code=2
			fake_dir=$directory
		fi
		
    # does the filename exist?
    if [[ ( -n "$file_basename" ) && ( ! -e "$file_basename" ) ]]; then
      # file does not exist error
      if [ "$exit_code" -eq 0 ]; then
        exit_code=3
      fi
    fi
    
    # get the absolute path of the current directory & change back to previous directory
    local abs_path="$(pwd -P)"
    cd "-" &>/dev/null
      
    # Append base filename to absolute path
    if [ "${abs_path}" = "/" ]; then
      abs_path="${abs_path}${fake_dir}${file_basename}"
    else
      abs_path="${abs_path}/${fake_dir}${file_basename}"
    fi
    
    # output the absolute path
    echo "$abs_path"
  
  fi
	
	return $exit_code
}

# Build file list
FILE_URLS=""
[[ -z "$QUIET" ]] && echo -e ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
[[ -z "$QUIET" ]] && echo -e "Opening file(s) with ${bldblk}$L_APP${txtrst}\n > ${bldblk}$L_USER@$L_HOST:$L_PORT${txtrst}\n < ${bldblk}$R_USER@$R_HOST:$R_PORT${txtrst}"
for var in "$@"
do    
    # Get absolute path to file
    rp=`truepath "$var"`
    truepath_exit_code=$?

    # Handle general errors
    if [ $truepath_exit_code -eq 1 ]; then
      echo " ! WARN: Could not get absolute path of ${txtund}$var${txtrst}, skipping"
      continue
    fi

    # Handle parent folder of specified file does not exist
    if [ $truepath_exit_code -eq 2 ]; then
      if [ -z "$CREATE_DIR" ]; then        
        echo " ! WARN: ${txtund}$var${txtrst} parent folder does not exist, skipping (use -f to create non-existant files and their parent folders)"
        continue
      else
        if [ -z "$SIMULATE_ONLY" ]; then
          # Create parent folder
          p=`dirname "$rp"`
          mkdir -p "$p"
        fi
      fi
    fi

    # Handle specified file does not exist
    if [ $truepath_exit_code -eq 2 ] || [ $truepath_exit_code -eq 3 ]; then
      if [ -z "$CREATE_FILE" ]; then
        echo " ! WARN: ${txtund}$var${txtrst} does not exist, skipping (use -c to create non-existant specified files)"
        continue
      else
        was_created=' (new)'
        if [ -z "$SIMULATE_ONLY" ]; then
          # Create file
          touch $var
        fi
      fi
    fi
    
    # Print absolute file name and created status
    [[ -z "$QUIET" ]] && echo " - $rp$was_created"
  
    # Add SFTP URL based on absolute file name to list
    FILE_URLS="${FILE_URLS} sftp://${R_USER}@${R_HOST}:${R_PORT}/${rp}"
done

# Check that at least one file was specified
if [ -z "$FILE_URLS" ]; then
  echo " X ERROR: List of files to open is empty"
  the_end
fi

# Define SSH command
SSH_CMD="ssh -p $L_PORT $L_USER@$L_HOST open -a $L_APP $FILE_URLS"

# Print SSH commmand
echo -e "$bldred$SSH_CMD$txtrst"

if [ -z "$SIMULATE_ONLY" ]; then
  # Run SSH command
  $($SSH_CMD)
  [[ -z "$QUIET" ]] && echo "Done"
else
  [[ -z "$QUIET" ]] && echo "Done (Simulation)"
fi

the_end



#
# red.sh uses a modified version of https://github.com/morgant/realpath which requires
#  the following information to be included in this script.
#

# 
# truepath - Convert a relative path to an absolute path. For each path specified it prints
#            the full path to STDOUT (even if the file doesn't exist) and returns:
#              * 0 on success
#              * 1 on general error
#              * 2 on file parent dir not found
#              * 3 on file not found
#
# Based on https://github.com/morgant/realpath
#
# realpath - Convert a relative path to an absolute path. Also verifies whether
#            path/file exists. For each path specified which exists, it prints
#            the full path to STDOUT and returns 0 if all paths exist on any
#            error or if any path doesn't exist.
#
# Based on http://www.linuxquestions.org/questions/programming-9/bash-script-return-full-path-and-filename-680368/page2.html#post4239549
# 
# CHANGE LOG:
# 
# v0.1        2012-02-18 - Morgan Aldridge <morgant@makkintosshu.com>
#                     Initial version.
# v0.2        2012-03-26 - Morgan Aldridge
#                     Fixes to incorrect absolute paths output for '/' and any
#                     file or directory which is an immediate child of '/' (when
#                     input as an absolute path).
# v0.3        2012-11-29 - Morgan Aldridge
#                     Fix for infinite loop in usage option and local paths 
#                     incorrectly assumed to be in root directory.
# v0.3-fork   2013-03-13 - Adam Jarret
#                     Return "true" path whether or not the file exists
#                     Renamed function so as not to conflict with actual realpath utility 
#                     Removed all interactive code
# 
# LICENSE:
# 
# Copyright (c) 2012, Morgan T. Aldridge. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
# 
# - Redistributions of source code must retain the above copyright notice, this 
#   list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright notice, 
#   this list of conditions and the following disclaimer in the documentation 
#   and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 

