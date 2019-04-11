#!/bin/bash
########## Configuration settings  ########
INPUT_DIRECTORY="/processing_Data/sanger_seq"
PATH_SANGER_FOLDER="/processing_Data/sanger_seq"
SHARED_FOLDER="/processing_Data/sanger_seq_users"
SANGER_SCRIPT="/processing_Data/sanger_process/sanger_script-v2.sh"
PROCESSED_FILE_DIRECTORY="/processing_Data/sanger_process"
PROCESSED_FILE_NAME="run_processed"

time=$(date +%T-%m%d%y)
echo "Initiating crontab - $time"

proc_file="$PROCESSED_FILE_DIRECTORY/$PROCESSED_FILE_NAME"
echo "$proc_file"

files=$(ls -t1 $INPUT_DIRECTORY/*.txt)

if [[ $files == ''  ]]; then
	echo "There are no files to process on folder $INPUT_DIRECTORY"
	echo "Exiting the script "
	echo "------------------------------------------"
	exit 1
fi

while read -r line ; do

	bn_file=$(basename $line)
	if ! grep -q $bn_file "$proc_file"; then
		echo "echo line :$line - $bn_file"
		path_folder=$(echo "$bn_file" | cut -d "." -f 1)
		if [[ ! -d $PATH_SANGER_FOLDER/$path_folder ]];then
			echo "Run folder $path_folder missing. Run not being processed..."
		    continue
		fi
		time=$(date +%T-%m%d%y)
		echo "Executing script $time: $SANGER_SCRIPT -f $INPUT_DIRECTORY/$bn_file -r $PATH_SANGER_FOLDER/$path_folder  -o $SHARED_FOLDER"
		$SANGER_SCRIPT -f $INPUT_DIRECTORY/$bn_file -r $PATH_SANGER_FOLDER/$path_folder  -o $SHARED_FOLDER
	else
		echo "Run already processed."
	fi

done <<<"$files"
