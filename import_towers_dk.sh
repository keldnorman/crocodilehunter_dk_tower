#!/bin/bash
#set -x
clear
#--------------------------------------------------------------------
# By Keld Norman, Aug 2020
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
 __//_____\\___    2000

EOF
#--------------------------------------------------------------------
# PATH TO UTILITIES
#--------------------------------------------------------------------
SOURCE_DIRECTORY_FOR_CROCODILEHUNTER="./crocodilehunter/src"
JQ="/usr/bin/jq"
MYSQL_CLIENT="/usr/bin/mysql"
MYSQL_INIT_SCRIPT="/etc/init.d/mysql"
MYSQL_PASSWORD="your_mysql_code_here"
PYTHON3="/usr/bin/python3"
IMPORT_GPSDATA_SCRIPT="./add_known_tower.py"
#--------------------------------------------------------------------
# VARIABLES
#--------------------------------------------------------------------
TOWER_DATA_FILE="/tmp/antenner.json"
TOWER_DATA_GPS_COORDINATES_FILE="/tmp/antenner.gps"
#--------------------------------------------------------------------
# CHECK IF JQ IS INSTALLED TO PROCESS JSON AND PYTHON3 TO IMPORT DATA
#--------------------------------------------------------------------
printf " - Checking for existence of needed utilities..\n"
if ! $(dpkg -l jq >/dev/null 2>&1) ; then 
 printf "\n ### ERROR - The utility ${JQ} is not installed!\n\n Install it with: \"apt-get update -qq -y && apt-get install jq\"\n\n"
 exit
else 
 if [ ! -x ${JQ} ]; then 
  printf "\n ### ERROR - I cant find the utility called ${JQ}\n\n Please alter the path to it in this script\n\n"
  exit
 fi
fi
if [ ! -x ${PYTHON3} ]; then 
  printf "\n ### ERROR - I cant find ${PYTHON3}\n\n Please install it or alter the path to the utility it in this script\n\n"
  exit
 fi
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
# FUNCTIONS
#--------------------------------------------------------------------
function trap_cleanup {
#--------------------------------------------------------------------
 for DELETE_FILE in ${TOWER_DATA_FILE} ${TOWER_DATA_GPS_COORDINATES_FILE}; do
  if [ -f ${DELETE_FILE} ]; then 
   echo   rm ${DELETE_FILE} >/dev/null 2>&1
  fi
 done
}
trap trap_cleanup EXIT
#--------------------------------------------------------------------
function select_database {
#--------------------------------------------------------------------
 printf " - Retrieving a list of used databases..\n"
 DATABASES=$(${MYSQL_CLIENT} -p${MYSQL_PASSWORD} --disable-column-names -e "show databases;"|egrep -v -e "information_schema|mysql|performance_schema")
 COUNT_DATABASES=$(echo "${DATABASES}"|wc -l)
 if [ ${COUNT_DATABASES} -ne 1 ]; then 
  printf "\n Found ${COUNT_DATABASES} database(s)\n\n"
  PS3="
  Please select the database you want to import the ${COUNT_TOWERS} celltower(s) coordinates in to: "
  select SELECT_DATABASE in ${DATABASES}; do
   if [ "${SELECT_DATABASE:-empty}" != "empty" ]; then
    DATABASE="${SELECT_DATABASE}"
    echo ""
    break
   else
    echo -e "\033[2A "
   fi
  done
  printf "\n"
 else
  DATABASE=${DATABASES}
  printf " - ### INFO Only one database found!\n"
 fi
  printf " - Database selected: \"${DATABASE}\"\n"
}
#--------------------------------------------------------------------
function download_data {
#--------------------------------------------------------------------
 printf " - Downloading the data from mastedatabasen.dk..\n"
 wget -q "https://mastedatabasen.dk/Master/antenner.json?maxantal=1000000&BBOX=441500,6049700,893400,6402330,EPSG:25832&tjenesteart=2" -O ${TOWER_DATA_FILE}
 if [ $? -ne 0 ]; then 
  printf "\n ### ERROR - An unknown error occured during the download of data!\n\n"
  exit
 fi
 if [ ! -f ${TOWER_DATA_FILE} ]; then 
  printf "\n ### ERROR - The download of the celltower data to the file ${TOWER_DATA_FILE} failed!\n\n"
  exit
 fi
}
#--------------------------------------------------------------------
function parse_data {
#--------------------------------------------------------------------
 if [ ! -s ${TOWER_DATA_FILE} ]; then 
  printf " - ### WARNING - The downloaded file containing the celltower data ( ${TOWER_DATA_FILE} ) was not found!\n"
  download_data 
 fi
 printf " - Parsing JSON data and extracting the GPS coordinates...\n"
 ${JQ} . ${TOWER_DATA_FILE}|egrep -e '"bredde"|"laengde"'|awk 'ORS=NR%2?FS:RS'|cut -d '"' -f 4,8|tr '"' ','|sort -n|uniq|awk '{print $1",Manual"}' > ${TOWER_DATA_GPS_COORDINATES_FILE}
 COUNT_TOWERS=$(cat ${TOWER_DATA_GPS_COORDINATES_FILE}|wc -l)
 printf " - Found ${COUNT_TOWERS} celltower GPS coordinates..\n"
}
#--------------------------------------------------------------------
# if [ ! -s ${TOWER_DATA_GPS_COORDINATES_FILE} ]; then 
#  printf " - ### WARNING - The parsed file containing the celltower coordinates ( ${TOWER_DATA_GPS_COORDINATES_FILE} ) was not found!\n"
#  parse_data
# else
#  COUNT_TOWERS=$(cat ${TOWER_DATA_GPS_COORDINATES_FILE}|wc -l)
# fi 
#--------------------------------------------------------------------
function import_data {
#--------------------------------------------------------------------
 if [ ! -f ${SOURCE_DIRECTORY_FOR_CROCODILEHUNTER}/${IMPORT_GPSDATA_SCRIPT} ]; then 
  printf "\n ### ERROR - I cant find the import gpsdata script ( ${SOURCE_DIRECTORY_FOR_CROCODILEHUNTER}/${IMPORT_GPSDATA_SCRIPT} )\n\n"
  exit 1
 fi
 if [ -z "${DATABASE}" ]; then 
  # printf " - ### WARNING - No database selected !\n"
  select_database
 fi
 printf " - Importing data in to the database \"${DATABASE}\"..\n\n"
 cd ${SOURCE_DIRECTORY_FOR_CROCODILEHUNTER}
 ${PYTHON3} ${IMPORT_GPSDATA_SCRIPT} ${DATABASE} ${TOWER_DATA_GPS_COORDINATES_FILE} |sed -e "s/added/ added/"|sed -e "s/rejected/ rejected/"
}
#--------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------
select_database
download_data
parse_data
import_data
printf "\n Done\n\n"
