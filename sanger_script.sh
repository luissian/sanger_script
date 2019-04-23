#!/bin/bash

# Exit immediately if a pipeline, which may consist of a single simple command, a list,
#or a compound command returns a non-zero status: If errors are not handled by user
set -e
# Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error when performing parameter expansion.

#Print everything as if it were executed, after substitution and expansion is applied: Debug|log option
#set -x

#=============================================================
# HEADER
#=============================================================

#INSTITUTION:ISCIII
#CENTRE:BU-ISCIII
#AUTHOR: Sara Monzon (smonzon@isciii.es)
#	 Luis Chapado (lchapado@externos.isciii.es)
VERSION=0.0.2
#CREATED: 23 April 2019
#
#ACKNOWLEDGE: longops2getops.sh: https://gist.github.com/adamhotep/895cebf290e95e613c006afbffef09d7
#
#DESCRIPTION: Sanger_script split the data sequencing to allow each user
#            get access of the sample information
#
#
#================================================================
# END_OF_HEADER
#================================================================

#SHORT USAGE RULES
#LONG USAGE FUNCTION
usage() {
	cat << EOF
This script reads sanger sequencing data and splits results into different folders for different users, sharing it with samba shares.
usage : $0 <-f file> <-r folder> -o <output_dir> [options]
	Mandatory input data:
	-f | Path to sanger run configuration file.ej. /Path/to/GN18-176A.txt
	-r | Path to sanger run folder. ej. /Path/to/GN18-176A
	-o | Output on remote dir. ej. /path/to/sanger_seq_users
	-v | version
	-h | display usage message
example: ./sanger_script.sh -f ../sanger_seq/GN18-176A.txt -r ../sanger_seq/GN18-176A -o ../sanger_seq_users/
EOF
}

#================================================================
# OPTION_PROCESSING
#================================================================
#Make sure the script is executed with arguments
if [ $# = 0 ]; then
	echo "NO ARGUMENTS SUPPLIED"
	usage >&2
	exit 1
fi

# Error handling
error(){
  local parent_lineno="$1"
  local script="$2"
  local message="$3"
  local code="${4:-1}"

	RED='\033[0;31m'
	NC='\033[0m'

  if [[ -n "$message" ]] ; then
    echo -e "\n---------------------------------------\n"
    echo -e "${RED}ERROR${NC} in Script $script on or near line ${parent_lineno}; exiting with status ${code}"
    echo -e "MESSAGE:\n"
    echo -e "$message"
    echo -e "\n---------------------------------------\n"
  else
    echo -e "\n---------------------------------------\n"
    echo -e "${RED}ERROR${NC} in Script $script on or near line ${parent_lineno}; exiting with status ${code}"
    echo -e "\n---------------------------------------\n"
  fi

  exit "${code}"
}


#DECLARE FLAGS AND VARIABLES
script_dir=$(dirname $(readlink -f $0))
cwd="$(pwd)"
is_verbose=false
#### CONFIGURATION FILES ON LOCAL SERVER
#
# TEMPORARY DIRECTORY WHERE SHARED CONFIGURATION FILE ARE SAVED BEFORE COPYING TO REMOTE SERVER
TMP_SAMBA_SHARE_DIR=/home/smonzon/Documents/desarrollo/sanger_script/tmp/shares
#
# LOCATION OF THE TEMPLATE FILE FOR CONFIG SAMBA SHARED FOLDERS
SAMBA_SHARE_TEMPLATE=/home/smonzon/Documents/desarrollo/sanger_script/template.conf
#
# FOLDER TO KEEP TRACK OF THE SHARED FOLDER FOR REMOVING AFTER RETENTION PERIOD
SAMBA_TRANSFERED_FOLDERS=/home/smonzon/Documents/desarrollo/sanger_script/transfered_folder/
#
# LOCATION OF THE TEMPLATE FILE FOR SENDING EMAILS
TEMPLATE_EMAIL=/home/smonzon/Documents/desarrollo/sanger_script/template_mail.htm
#

####################################################
#### CONFIGURATION FILES ON REMOTE SERVER
#
# DIRECTORY ON THE REMOTE SERVER, WHERE THE SHARED FILES WILL BE COPY
REMOTE_SAMBA_SHARE_DIR=/etc/samba/shares
#
# USER USED FOR REMOTE LOGIN
REMOTE_USER="root"
#
# REMOTE SERVER WHERE TO COPY THE OUTPUT FILES
REMOTE_SAMBA_SERVER="barbarroja"

#SET COLORS

YELLOW='\033[0;33m'
WHITE='\033[0;37m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

#PARSE VARIABLE ARGUMENTS WITH getops
#common example with letters, for long options check longopts2getopts.sh
options=":f:r:o:Vvh"
while getopts $options opt; do
	case $opt in
		f )
			sanger_file=$OPTARG
			;;
		r )
			run_folder=$OPTARG
			;;
		o )
			remote_ouput_dir=$OPTARG
			;;
		V )
			is_verbose=true
			log_file="/dev/stdout"
			;;
		h )
		  	usage
		  	exit 1
		  	;;
		v )
		  	echo $VERSION
		  	exit 1
		  	;;
		\?)
			echo "Invalid Option: -$OPTARG" 1>&2
			usage
			exit 1
			;;
		: )
      		echo "Option -$OPTARG requires an argument." >&2
      		exit 1
      		;;
      	* )
			echo "Unimplemented option: -$OPTARG" >&2;
			exit 1
			;;

	esac
done
shift $((OPTIND-1))

#================================================================
# MAIN_BODY
#================================================================

function join_by { local IFS="$1"; shift; echo "$*"; }


printf "\n\n%s"
printf "${YELLOW}------------------${NC}\n"
printf "%s"
printf "${YELLOW}Starting Sanger Script version:${VERSION}${NC}\n"
printf "%s"
printf "${YELLOW}------------------${NC}\n\n"


date=`date +%Y%m%d`

run_name=$(basename $sanger_file | sed 's/.txt//g')
if [ ! -f "$sanger_file" ] ; then
    echo "$0: File '${sanger_file}' not found "
    exit 1
fi
# remove the heading lines from file and replace tabs by commas
tmp=$(tail -n+6 "$sanger_file")
var_file="${tmp//$'\t'/,}"

## Read txt file line by line and create folders per user, copying the files in each respective folder.
while read -r line ;do
    comment=$(echo $line | cut -d "," -f 3 )
    # remove the space at the end if exists
    comment=$(sed 's/ *$//' <<<$comment)
    # print an error in case the comment column contains more than 1 username and it is not sepparated by ":" but space
    if  [[ $comment == *" "* ]] ; then
        printf "${RED}Unable to process the sample on the line $line ${NC}\n"
        printf "${RED}There are spaces in comment field ${NC}\n"
        continue
    fi
    #IFS=':' read -r -a emails <<< "$comment"
    emails=$(echo $comment | sed 's/:/,/g')
    user_names=$(echo $comment | sed 's/@isciii.es//g' | sed 's/@externos.isciii.es//g')

    #IFS=':' read -r -a users <<< "$comment"
    IFS=':' read -r -a users <<< "$user_names"
    allowed_users=$(join_by _ "${users[@]}")

    well=$(echo $line | cut -d "," -f 1)
    sample_name=$(echo $line | cut -d "," -f 2)
	echo $sample_name
##  if [ ! -d $output_dir/$date"_"$run_name"_"$allowed_users ]; then
##        mkdir -p $output_dir/$date"_"$run_name"_"$allowed_users
##        echo "Creating directory for $date"_"$run_name"_"$allowed_users"
##	echo $emails > $output_dir/$date"_"$run_name"_"$allowed_users/user_allowed.txt
##    fi
    folder_name=tmp/$date"_"$run_name"_"$allowed_users
    if [ ! -d $folder_name ]; then
        mkdir -p $folder_name
        echo "Creating directory for $date"_"$run_name"_"$allowed_users"
        echo $emails > $folder_name/user_allowed.txt
    fi
	echo $run_folder
	echo "Copying files to temporary user share folder"
    rsync -rlv $run_folder/*$sample_name* $folder_name || error ${LINENO} $(basename $0) "Sequencing files couldn't be copied to tmp folder"
    if [ ! -d $SAMBA_TRANSFERED_FOLDERS ]; then
		mkdir -p $SAMBA_TRANSFERED_FOLDERS
    fi
    touch $SAMBA_TRANSFERED_FOLDERS/$date"_"$run_name"_"$allowed_users
#done < $sanger_file

done <<<"$var_file"

## Copy created shared folders to remote file system server
rsync -vr tmp/ $REMOTE_USER@$REMOTE_SAMBA_SERVER:$remote_ouput_dir/ || error ${LINENO} $(basename $0) "Shared folders couldn't be copied to remote filesystem server."

## Create samba shares.
if [ ! -d $TMP_SAMBA_SHARE_DIR ]; then
    mkdir -p $TMP_SAMBA_SHARE_DIR
fi

# fetch the remote Samba includes file
echo "Fetching samba includes file from filesystem file server."
scp $REMOTE_USER@$REMOTE_SAMBA_SERVER:$REMOTE_SAMBA_SHARE_DIR/includes.conf $TMP_SAMBA_SHARE_DIR || error ${LINENO} $(basename $0) "Failed fetching of samba includes file"

for folder in $(ls tmp | grep $run_name);do
	echo "Processing folder: $folder"
	users=$(echo $folder | cut -d "_" -f3- | sed 's/_/,/g')
	echo "Folder $folder is accesible for users: $users"
	sed "s/##FOLDER##/$folder/g" $SAMBA_SHARE_TEMPLATE | sed "s/##USERS##/$users/g" > $TMP_SAMBA_SHARE_DIR/$folder".conf"
	echo "include = $samba_share_dir/${folder}.conf" >> $TMP_SAMBA_SHARE_DIR/includes.conf
	emails=$(cat tmp/$folder/user_allowed.txt)
	#scp lchapado@barbarroja.isciii.es:$SAMBA_SHARE_DIR/$folder".conf" /etc/samba/
	emails=$(cat tmp/$folder/user_allowed.txt)

	number_files=$( ls -t1 tmp/$folder | wc -l )
	echo -e "$folder\t$date\t$users\t$number_files" >> $script_dir/samba_folders

	echo "Sending email"
	sed "s/##FOLDER##/$folder/g" $template_email | sed "s/##USERS##/$users/g" | sed "s/##MAILS##/$emails/g" | sed "s/##RUN_NAME##/$run_name/g"> tmp/mail.tmp
	## Send mail to users
	/usr/sbin/sendmail -t < tmp/mail.tmp

	echo "mail sended"

	echo "Deleting mail temp file"
	rm tmp/mail.tmp

done
# Copy shared configuration files to remote
echo "Copying samba shares configuration to remote filesystem server"
rsync -rlv $TMP_SHARE_DIR $REMOTE_USER@$REMOTE_SAMBA_SERVER:$REMOTE_SAMBA_SHARE_DIR/ || error ${LINENO} $(basename $0) "Shared samba config files couldn't be copied to remote filesystem server."

echo "Restarting samba service"
## samba service restart
pssh -A -H $REMOTE_USER@REMOTE_SAMBA_SERVER -o . '/sbin/service smb restart'

echo "File $sanger_file process has been completed"
