#!/bin/bash
########## Configuration settings  ########
RETENTION_TIME="+7"
SHARED_FOLDER="/srv/sanger_script/share/"

date=`date +%Y-%m-%d`


echo "Executing script for Deleting old shared files"
echo "Date is : $date"
###  delete shared folder older than the days in RETENTION_TIME ###
find $SHARED_FOLDER* -type d  -mtime $RETENTION_TIME -exec rm -rf -- '{}' \;

echo "backup script completed"
