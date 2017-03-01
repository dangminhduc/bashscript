#/bin/bash
S3_BUCKET_TARGET=""
echo $S3_BUCKET_TARGET
# Execute gitlab-backup
/opt/gitlab/bin/gitlab-rake gitlab:backup:create
sleep 10

#Upload the newest file to S3 folder
echo "upload backup file to s3 bucket"
FILE_TO_UPLOAD=`ls -Art /var/opt/gitlab/backups/*gitlab_backup.tar | tail -n 1`
echo $FILE_TO_UPLOAD
aws s3 cp $FILE_TO_UPLOAD $S3_BUCKET_TARGET
sleep 5

#Delete the uploaded file
echo "delete uploaded file:$FILE_TO_UPLOAD"
rm -rf $FILE_TO_UPLOAD

# List file for sure
ls -l /var/opt/gitlab/backups
