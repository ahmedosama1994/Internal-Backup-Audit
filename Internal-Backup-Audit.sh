#!/bin/bash
## Use it like: bash /orkitools/backupaudit.sh daily >> /orkitools/auditreport.txt
date=$(date +"%F")
exit_code=0
type=$1 #daily,weekly or monthly
mailacc=""
#TodayDate
ttime ()
{
 ttime=$(date +%d-%m-%Y)
 echo -e "$ttime $1"
}
#To compare a random file in the system and its copy in the backup using md5sum

checkingafile() {

 fileonthesystem=$(md5sum /etc/fstab | cut -d " " -f 1)
 fileonthebackup=$(md5sum /backup/daily.0/os/etc/fstab | cut -d " " -f 1)
if [ $fileonthesystem = $fileonthebackup ]; then
 ttime "Checking a file on the system succeeded"
else
 exit_code=1
 ttime  "There is no /etc/fstab file in backup today, check OS backup"
fi
}

#To compare home size and home size in backup (cPanel servers)

cpanelhome() {
findvm=$(find /home -type f -iname *.qcow2 -o -iname *.raw)
vm=$(echo $findvm | cut -d "/" -f 3-)
sum=0
for f in $(ls /var/cpanel/userdata/ |grep -v nobody)
do
 backup=$(du -s /backup/daily.0/$date/accounts/$f/homedir/ |awk '{print $1}')
 sum=`expr $sum + $backup`
done
 home=$(du -sc /home --exclude='backuppc' --exclude='virtfs' --exclude=$vm |grep -i total |awk '{print $1}' |sed 's/[^0-9]*//g')
 homeinit=`expr $home \* 90 / 100`
if [[ $sum -gt $homeinit ]]; then
 ttime  "The home backup has been taken successfully"
else
 exit_code=1
 ttime "The home backup is less than 90% of the home directory"
fi
}

# To compare OS size and OS size in backup (cPanel servers)

cpanelos() {
osfiles=$(du --exclude='httpd/logs' /etc/ --exclude='tmpDSK' --exclude='local/cpanel/logs' /usr/ /lib/ /lib64/ /opt/ /bin/ /sbin/ /boot/ /root/ /orkitools/ /scripts/ --exclude='lib/mysql' --exclude='log' --exclude='run' --exclude='tmp' /var/ -sc |grep -i total |awk '{print $1}')


osfilesbackup=$(du -s /backup/daily.0/os/ |awk '{print $1}')

osinit=`expr $osfiles \* 75 / 100`
if [[ $osfilesbackup -gt $osinit ]]; then
 ttime  "The OS backup has been taken successfully"
else
 exit_code=1
 ttime  "The OS backup is less than 75% of the OS files"
fi
}

## To compare OS size and OS size in backup (non-cPanel servers)

noncpanelos() {

osfiles=$(du --exclude='httpd/logs' /etc/ --exclude='tmp '/usr/ /lib/ /lib64/ /opt/ /bin/ /sbin/ /boot/ /root/ /orkitools/ --exclude='lib/mysql/' --exclude='log' --exclude='run' --exclude='tmp' /var/ -sc |grep -i total |awk '{print $1}')
osfilesbackup=$(du -s /backup/daily.0/os/ |awk '{print $1}')
osinit=`expr $osfiles \* 75 / 100`
if [ $osfilesbackup -gt $osinit ]; then
 ttime  "The OS backup has been taken successfully"
else
 exit_code=1
 ttime  "The OS backup is less than 75% of the OS files"
fi

}

## To compare home size and home size in backup (non-cPanel servers)

homenoncpanel() {

home=$(du -sc /home |grep -i total |awk '{print $1}' |sed 's/[^0-9]*//g')
backuphome=$(du -sc /backup/daily.0/home |grep -i total |awk '{print $1}' |sed 's/[^0-9]*//g')

homeinit=`expr $home \* 90 / 100`
if [ $backuphome -gt $homeinit  ]; then

 ttime  "The home backup has been taken successfully "

else
 exit_code=1
 ttime "The home backup is less than 90% of the home directory"

fi
}

#Checking dump of all databases (cPanel servers)

dbcpanel() {
for f in $(ls /var/cpanel/userdata/ |grep -v nobody)
do
user=$f
database=$(ls -ltr /backup/daily.0/$date/accounts/$user/mysql |grep .sql |grep -v roundcube.sql |tail -1 | awk 'NF>1{print $NF}')

 grep  -i -m 1 "Dump completed" /backup/daily.0/$date/accounts/$user/mysql/$database &> /dev/null
sc=$?
if [ $sc = 0  ]; then
 ttime "Dump has been completed on the database: $database for user: $user"
elif [ $sc = 2  ]; then
 ttime "No databases for user: $user"
else
 exit_code=1
 ttime "Dump failed on database: $database for user: $user"
fi

done
}

#Checking dump of all databases (non-cPanel servers)

dbnoncpanel() {
#backupdbcounts=$(ls /backup/daily.0/dbbackup/ |wc -l)
#n=`expr $backupdbcounts \* 2 + 3`
#logcounts=$(tail -n$n /var/log/dbbackup |grep -i "has been backed up successfully" |wc -l)

#if [ $backupdbcounts = $logcounts ]; then
# echo "Dump has been completed successfully"
#else
# echo "Dump failed"
#fi
for f in $(ls /backup/daily.0/dbbackup/)
do
DB=$f
zgrep -i "Dump completed" /backup/daily.0/dbbackup/$DB &> /dev/null
if [ "$?" = 0 ]; then
 ttime "Dump has been completed on $DB"
else
 exit_code=1
 ttime "Dump error on database $DB"
fi

done

}

#To compare a random file in home directory and its copy in the backup using md5sum (cPanel servers)

checkingafilehomecpanel() {
user=$(ls /var/cpanel/userdata/ |grep -v nobody | head -1)
ls -a /backup/daily.0/$date/accounts/$user/homedir/public_html |egrep '.htaccess|index.*' &> /dev/null 
if [ "$?" = 0 ]; then
 ttime  "Checking a file in a home directory succeeded"
else
 exit_code=1
 ttime  "There is no .htaccess for user $user in /backup/daily.0/$date/accounts/$user/homedir/public_html, check home backup"
fi
}

#To compare a random file in home directory and its copy in the backup using md5sum (non-cPanel servers)


checkingafilehomenoncpanel() {
user=$(find /home/ -type d -iname public_html |head -n1)

ls -a /backup/daily.0/home/$user |egrep '.htaccess|index.*' &> /dev/null

if [ "$?" = 0 ]; then
 ttime "Checking a file in a home directory succeeded"
else
 exit_code=1
 ttime "There is no .htaccess for user $user in /backup/daily.0/$user, check home backup"
fi
}

#Checking if rsnapshot run today

backupdate() {
rsnapshotdate=$(tail -n1 /var/log/rsnapshot |cut -c1-11 |cut -c2-)

todaydate=$(echo $(date +"%F"))
if [ $rsnapshotdate = $todaydate ]; then
 ttime  "Backup has been taken today "
else
 exit_code=1
 ttime "No backup has been taken today"
fi
}

#To check when cpanel backup process finish to start auditing 

cpanelbackup() {
while true
do
 ps aux |grep /usr/local/cpanel/bin/backup |grep -v "grep --color=auto -i /usr/local/cpanel/bin/backup" |grep -v "grep /usr/local/cpanel/bin/backup" &> /dev/null
 if [ "$?" -ne 0 ]
  then
  break
fi
sleep 100
done
}
log () {

ttime > /dev/null
data=$(cat /orkitools/auditreport.txt |grep $ttime)

}
checkingtype() {
if [ $type == "daily" ]; then
  ttime "Daily backup:"
elif [ $type == "weekly" ]; then
  ttime "Weekly backup:"
else
  ttime "Monthly backup:"
fi


}
checkingtype
#Checking cPanel server or not 

cpanel=/usr/local/cpanel/cpanel


if [ -e $cpanel ]; then
# Pass daily, weekly or monthly
 rsnapshot $1
 if [ $type == "daily" ]; then
# rsnapshot $1
 cpanelbackup
 if [ "$?" = 0 ]; then

 backupdate
 ttime "Last backup status: $(tail -n1 /var/log/rsnapshot)"
 cpanelos
 cpanelhome
 checkingafile
 checkingafilehomecpanel
 dbcpanel
if [ "$exit_code" == "1" ]; then
 ttime "The auditing finished with many parts that did not take succussefully"
 log
 mail -s "$HOSTNAME backup has been finished with errors" $mailacc <<< "The auditing finished with many parts that did not take succussefully,$data"
else
 ttime "All checks are OK"
 log
 mail -s "$HOSTNAME backup succeeded" $mailacc <<< "The backup has been taken successfully $data "
fi
else 
 log
 mail -s "$HOSTNAME backup failed" $mailacc <<< "Error while taking backup/rsnapshot process did not start, $data"

fi
fi
else
  rsnapshot $1
if [ "$?" = 0 ]; then
  backupdate
  ttime "Last backup status:  $(tail -n2 /var/log/rsnapshot)"
  homenoncpanel
  checkingafile
  checkingafilehomenoncpanel
  noncpanelos
  dbnoncpanel
if [ "$exit_code" == "1" ]; then
 ttime "The auditing finished with many parts that did not take succussefully"
 log
 mail -s "$HOSTNAME backup has been finished with errors" $mailacc <<< "The auditing finished with many parts that did not take succussefully,$data"
 
 
else
  ttime "All checks are OK"
  log
  mail -s "$HOSTNAME backup succeeded" $mailacc <<< "The backup has been taken successfully $data "
fi
else
 log
 mail -s "$HOSTNAME backup failed" $mailacc <<< "Error while taking backup/rsnapshot process did not start $data"

fi
fi
