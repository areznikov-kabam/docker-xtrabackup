#!/bin/bash
set -x

xtrabackup --version

if [ -z "$backup_folder" ]; then
    echo "Need to set backup_folder"
    exit 1
fi

pushd $backup_folder
rm *.tar
dst_dir=`ls -d *full*`
rm -rvf /var/lib/mysql/*

ls -lh $dst_dir
echo "datadir=/var/lib/mysql" >> $dst_dir/backup-my.cnf
echo "secure_file_priv=''" >> $dst_dir/backup-my.cnf
echo "tmpdir=/tmp" >> $dst_dir/backup-my.cnf
cp -vf $dst_dir/backup-my.cnf /etc/my.cnf
cp -vf $dst_dir/backup-my.cnf /etc/mysql/my.cnf

for i in `ls -d *`
do
innobackupex --decompress $i
done

innobackupex  --apply-log --redo-only `readlink -f $dst_dir`

for i in `ls -d *increment*`
do
innobackupex --apply-log --redo-only `readlink -f $dst_dir` --incremental-dir=`readlink -f $i`
done

innobackupex --apply-log `readlink -f $dst_dir`



ls -la /var/lib/mysql
innobackupex  --defaults-file=/etc/mysql/my.cnf --copy-back `readlink -f $dst_dir`
ls -la /var/lib/mysql
if [ $? -ne 0 ]; then
    echo "Error: applying log to backup backup data failed!!!" >&2
    rm -rf $tmp_dir
    exit 1
fi

echo "Backup is ready!!" >&2

mkdir -p /backup/RESULT /tmp/RESULT
chown -R mysql:mysql /var/lib/mysql
chown -R mysql:mysql /backup/RESULT /tmp/RESULT

cat /etc/my.cnf


su -c "mysqld_safe --defaults-file=$dst_dir/backup-my.cnf --user=root --datadir=/var/lib/mysql --skip-grant-tables" -m mysql
cat /var/lib/mysql/*.err