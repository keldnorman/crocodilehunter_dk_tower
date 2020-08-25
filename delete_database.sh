#!/bin/bash
#set -x
clear
#--------------------------------------------------------------------
# By Keld Norman, Aug 2020
#--------------------------------------------------------------------
MYSQL_PASSWORD="toor" # Your database password
#--------------------------------------------------------------------
# BANNER for the 1337'ish ness
#--------------------------------------------------------------------
cat << "EOF"


       ^             ^
       |             |
       +            THE
       |          DANISH
       A         CELLTOWER
      ===       GPS POSITION
     /EEE\       RETRIEVER
    //EEE\\       SCRIPT
 __//_____\\___    2000 DATABASE DELETER.....

EOF
#--------------------------------------------------------------------
# PATH TO UTILITIES
#--------------------------------------------------------------------
MYSQL_CLIENT="/usr/bin/mysql"
MYSQL_INIT_SCRIPT="/etc/init.d/mysql"
#--------------------------------------------------------------------
# VARIABLES
#--------------------------------------------------------------------
TOWER_DATA_FILE="/tmp/antenner.json"
TOWER_DATA_GPS_COORDINATES_FILE="/tmp/antenner.gps"
SOURCE_DIRECTORY_FOR_CROCODILEHUNTER="./crocodilehunter/src"
#--------------------------------------------------------------------
# CHECK IF MYSQL IS INSTALLED AND RUNNING
#--------------------------------------------------------------------
printf " - Checking if MySQL is running..\n"
if [ ! -x ${MYSQL_CLIENT} ]; then
 printf "\n ### ERROR - I cant find the utility called ${MYSQL_CLIENT}\n\n Please alter the path to it in this script\n\n"
 exit
fi
if [ ! -f ${MYSQL_INIT_SCRIPT} ]; then
 printf "\n ### ERROR - I cant find the mysql server start/stop utility ${MYSQL_INIT_SCRIPT}\n\n Please alter the path to it in this script\n\n"
 exit
fi
${MYSQL_INIT_SCRIPT} status 2>&1 | grep -q "stopped\|dead"
if [ $? -eq 0 ]; then
 printf " - ### WARNING - MySQL not running - attempting to start it..\n"
 ${MYSQL_INIT_SCRIPT} start > /dev/null 2>&1
 ${MYSQL_INIT_SCRIPT} status 2>&1 | grep -q "stopped\|dead"
 if [ $? -eq 0 ]; then
  printf "\n ### ERROR - Starting MySQL failed - exiting script\n\n"
  exit
 fi
fi
#--------------------------------------------------------------------
function select_database {
#--------------------------------------------------------------------
 printf " - Retrieving a list of used databases..\n"
 DATABASES=$(${MYSQL_CLIENT} -p${MYSQL_PASSWORD} --disable-column-names -e "show databases;"|egrep -v -e "information_schema|mysql|performance_schema")
 COUNT_DATABASES=$(echo "${DATABASES}"|wc -w)
 if [ ${COUNT_DATABASES} -eq 0 ]; then
  printf " - ### ERROR - No databases found to delete!\n\n"
  exit
 fi
 if [ ${COUNT_DATABASES} -eq 1 ]; then
  DATABASE=${DATABASES}
  read -p " Only one database found: \"${DATABASE}\" do you want to delete it (y/n)?: \n" -n 1 -r
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    exit 1
  fi
 else
  printf "\n Found ${COUNT_DATABASES} database(s)\n\n"
  PS3="
  Please select the database you want to delete: "
  select SELECT_DATABASE in ${DATABASES}; do
   if [ "${SELECT_DATABASE:-empty}" != "empty" ]; then
    DATABASE="${SELECT_DATABASE}"
    break
   else
    echo -e "\033[2A "
   fi
  done
 fi
 printf "\n - Database selected: \"${DATABASE}\"\n"
}
#--------------------------------------------------------------------
function delete_database {
#--------------------------------------------------------------------
 printf " - Deleting database..\n\n"
 ${MYSQL_CLIENT} -p${MYSQL_PASSWORD} -e "drop database ${DATABASE};"
 if [ $? -ne 0 ]; then 
  printf "\n ### ERROR - Failed to delete database ${DATABASE} !\n\n"
 else
  printf " ### SUCCESS: Database ${DATABASE} deleted.\n\n"
 fi
}
#--------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------
select_database
delete_database
