# !/bin/bash
######################################################
# Script que cria a estrutura necessaria
######################################################

mkdir /backup
mkdir /script/log -p
touch /backup/id
echo "0" > /backup/id
wget https://raw.githubusercontent.com/gonzaloctorres/backup/main/parametros.conf -O /script/parametros.conf
wget https://raw.githubusercontent.com/gonzaloctorres/backup/main/backup.sh -O /script/backup.sh
chmod 777 /script/backup.sh
echo "0 1 * * * wget https://raw.githubusercontent.com/gonzaloctorres/backup/main/backup.sh -O /script/backup.sh >/dev/null 2>&1" >> /var/spool/cron/root
echo "0 0,6,12,18 * * * /script/backup.sh >/dev/null 2>&1" >> /var/spool/cron/root
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
aws configure
