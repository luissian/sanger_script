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
#		 Luis Chapado (lchapado@isciii.es)
VERSION=0.0.1
#CREATED: 16 October 2018
#
#ACKNOWLEDGE: longops2getops.sh: https://gist.github.com/adamhotep/895cebf290e95e613c006afbffef09d7
#
#DESCRIPTION: plasmidID is a computational pipeline tha reconstruct and annotate the most likely plasmids present in one sample
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
	-o | Output dir. ej. /path/to/sanger_seq_users
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
samba_share_template=/home/smonzon/Documents/desarrollo/sanger_script/samba/template.conf
samba_share_dir=/home/smonzon/Documents/desarrollo/sanger_script/samba/shares
template_email=/home/smonzon/Documents/desarrollo/sanger_script/template_mail.htm
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
			output_dir=$OPTARG
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

    if [ ! -d $output_dir/$date"_"$run_name"_"$allowed_users ]; then
        mkdir -p $output_dir/$date"_"$run_name"_"$allowed_users
        echo "Creating directory for $date"_"$run_name"_"$allowed_users"
	echo $emails > $output_dir/$date"_"$run_name"_"$allowed_users/user_allowed.txt
    fi
    folder_name=$date"_"$run_name"_"$allowed_users
    cp $run_folder/*$sample_name* $output_dir/$folder_name || error ${LINENO} $(basename $0) "Sequencing files couldn't be copied to samba share folder"
#done < $sanger_file

done <<<"$var_file"

## Create samba shares.

for folder in $(ls $output_dir | grep $run_name);do
	echo "Processing folder: $folder"
	users=$(echo $folder | cut -d "_" -f3- | sed 's/_/,/g')
	echo "Folder $folder is accesible for users: $users"
	sed "s/##FOLDER##/$folder/g" $samba_share_template | sed "s/##USERS##/$users/g" > $samba_share_dir/$folder".conf"
	echo "include = $samba_share_dir/${folder}.conf" >> $samba_share_dir/includes.conf
	emails=$(cat $output_dir/$folder/user_allowed.txt)
	## samba service restart

	echo "Restarting samba service"
	/sbin/service smb restart

	number_files=$( ls -t1 $output_dir/$folder | wc -l )
	echo -e "$folder\t$date\t$users\t$number_files" >> $script_dir/samba_folders
	echo "sending email"
	sed "s/##FOLDER##/$folder/g" $template_email | sed "s/##USERS##/$users/g" | sed "s/##MAILS##/$emails/g" | sed "s/##RUN_NAME##/$run_name/g"> mail.tmp
	## Send mail to users
	/usr/sbin/sendmail -t < mail.tmp

	echo "mail sended"

	echo "Deleting mail temp file"
	rm mail.tmp

done

echo "${run_name}.txt" >> $script_dir/run_processed
echo "File $sanger_file process has been completed"
