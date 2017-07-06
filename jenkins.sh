#!/bin/bash

#env VARIABLES
# ACCESS_KEY  XXXXX
# SECRET_KEY  XXXXX
# S3_BUCKET s3://XXXXXX
# DB_NAME    XXXXXX

TODAY=`date +%F`

#find lastest full backup date
LAST_FULL_BACKUP=`/usr/local/bin/s3cmd --access_key=$ACCESS_KEY --secret_key=$SECRET_KEY ls -r  $S3_BUCKET | sort | grep full | tail -1  | awk '{print $NF}'`
LAST_FULL_BACKUP_PATH=`dirname $LAST_FULL_BACKUP`
LAST_FULL_BACKUP_FILENAME=`basename $LAST_FULL_BACKUP`

echo $LAST_FULL_BACKUP_PATH
echo $LAST_FULL_BACKUP_FILENAME


#sync backup folder
mkdir -p ./tmp
rm -rf ./tmp/1
mkdir -p ./tmp/1
/usr/local/bin/s3cmd --access_key=$ACCESS_KEY --secret_key=$SECRET_KEY sync $LAST_FULL_BACKUP_PATH/ ./tmp/1/

pushd ./tmp/1/
for i in *.tar
do
	ls -la $i
	tar -xf $i
done

for i in `ls -d */`
do
        file $i
done

popd

mkdir -p ./tmp/RESULT
ROOT=`readlink -f ./tmp`
cid=$(docker run --detach -v $ROOT:/backup:rw --env backup_folder=/backup/1 kabamareznikov/xtrabackup_vanilla)

sleep 60
docker  logs $cid

docker exec $cid mysqldump --tab=/backup/RESULT --fields-terminated-by=, --fields-enclosed-by=\" --lines-terminated-by=0x0d0a $DB_NAME -h 127.0.0.1 --port 3306
docker exec  $cid mysqladmin shutdown

tar -cpzvf $DB_NAME-$TODAY.tar.gz ./tmp/RESULT/

/usr/local/bin/s3cmd --access_key=$ACCESS_KEY --secret_key=$SECRET_KEY put $DB_NAME-$TODAY.tar.gz $S3_BUCKET/export/$DB_NAME-$TODAY.tar.gz