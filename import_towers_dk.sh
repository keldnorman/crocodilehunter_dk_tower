#!/bin/bash
#set -x
clear
#--------------------------------------------------------------------
# By Keld Norman, Aug 2020
#--------------------------------------------------------------------
# THINGS YOU MIGHT NEED TO ALTER:
#--------------------------------------------------------------------
MYSQL_PASSWORD="your-database-password"
LSUSB_GPS_NAME="PL2303" # The name of your USB GPS when running lsusb
IMPORT_GPSDATA_SCRIPT="/root/source/4G_Crocodilehunter/crocodilehunter/src/add_known_tower.py"
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
JQ="/usr/bin/jq"
WGET="/usr/bin/wget"
PYTHON3="/usr/bin/python3"
MYSQL_CLIENT="/usr/bin/mysql"
MYSQL_INIT_SCRIPT="/etc/init.d/mysql"
DIRNAME="/usr/bin/dirname"
#--------------------------------------------------------------------
# VARIABLES
#--------------------------------------------------------------------
TOWER_DATA_FILE="/tmp/antennas.json"
TOWER_DATA_GPS_COORDINATES_FILE="/tmp/antennas.gps"
#--------------------------------------------------------------------
# CHECK IF TOOLS NEEDED HAVE BEEN INSTALLED
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
if [ ! -x ${DIRNAME} ]; then 
 printf "\n ### ERROR - I cant find ${DIRNAME}\n\n Please install coreutils (apt-get install coreutils)\n\n"
 exit
fi
if [ ! -x ${PYTHON3} ]; then 
 printf "\n ### ERROR - I cant find ${PYTHON3}\n\n Please install it or alter the path to the utility it in this script\n\n"
 exit
fi
if [ ! -x ${WGET} ]; then 
 printf "\n ### ERROR - I cant find ${WGET}\n\n Please install it or alter the path to the utility it in this script\n\n"
 exit
fi
# MY GPS IS CALLED PL2303 WHEN I RUN:  lsusb
printf " - Checking for existence of a GPS..\n"
if [ $(lsusb|grep -c "${LSUSB_GPS_NAME}") -eq 0 ]; then
 printf " ### ERROR - No GPS detected!\n\n"
 exit 1
fi
SOURCE_DIRECTORY_FOR_CROCODILEHUNTER="$(${DIRNAME} ${IMPORT_GPSDATA_SCRIPT})"
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
 systemctl stop gpsd.socket  >/dev/null 2>&1
 systemctl stop gpsd.service >/dev/null 2>&1
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
  Please select the database you want to use: "
  select SELECT_DATABASE in ${DATABASES}; do
   if [ "${SELECT_DATABASE:-empty}" != "empty" ]; then
    DATABASE="${SELECT_DATABASE}"
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
function ask_for_download_of_tower_data {
#--------------------------------------------------------------------
echo ""
while true; do
    read -p " Do you wish to download and import DK Cell-tower GPS positions in to the database (y/n) ?: " yn
    case $yn in
        [Yy]* ) IMPORT=1 ;
                if [ ! -f ${SOURCE_DIRECTORY_FOR_CROCODILEHUNTER}/${IMPORT_GPSDATA_SCRIPT} ]; then 
                 printf "\n ### ERROR - I cant find the import gpsdata script ( ${SOURCE_DIRECTORY_FOR_CROCODILEHUNTER}/${IMPORT_GPSDATA_SCRIPT} )\n\n"
                 exit 1
                fi
                break ;;
        [Nn]* ) IMPORT=0 ; RADIUS=0 ; break ;;
        * ) printf "\n Please answer yes or no!\n\n";;
    esac
done
if [ ${IMPORT:-0} -ne 1 ]; then
 return
fi
#---------------------- 
 printf "\n Select the RADIUS from your current position You want to download GSM data from.\n\n"
  PS3="
 What type of GSM tower data do you want to use ?: "
  select SELECT_GSM_DATA in "Download GSM data for all of Denmark" "Download GSM data from a limited area" "Skip downloading GSM tower location data"; do
   if [ "${SELECT_GSM_DATA:-empty}" != "empty" ]; then
    case ${SELECT_GSM_DATA} in
     "Download GSM data for all of Denmark")     RADIUS=50000   ; break ;;
     "Download GSM data from a limited area")    ask_for_radius ; break ;;
     "Skip downloading GSM tower location data") RADIUS=0       ; break ;;
     * ) printf "\n Invalid selection - try again!\n";;
    esac
   else
    echo -e "\033[2A "
   fi
  done
}
#---------------------------------------
function ask_for_radius {
#---------------------------------------
RADIUS=0
while [ ${RADIUS:-0} -eq 0 ]; do
 echo ""
 read -p " Enter the radius in meters from your current position you want to import tower data from ( max 50000 / default 5000 ): " userinput
 if [ ! -z "${userinput}" ]; then 
  if [[ $userinput =~ ^[[:digit:]]+$ ]] ; then 
   if [[ $userinput -lt 0 || $userinput -gt 50000 ]] ; then 
    printf "\n Input outside acceptable range - try again!\n"
    RADIUS=0
   else
    RADIUS=${userinput}
   fi
  else
   printf "\n Input outside acceptable range - try again!\n"
   RADIUS=0
  fi
 else
  printf "\n Input outside acceptable range - try again!\n"
  RADIUS=0
 fi 
done
}
#---------------------------------------
function initialize_gps {
#---------------------------------------
 systemctl stop gpsd.socket >/dev/null 2>&1
 systemctl stop gpsd.service >/dev/null 2>&1
 systemctl start gpsd.socket >/dev/null 2>&1
 systemctl start gpsd.service >/dev/null 2>&1
}
#---------------------------------------
function get_current_gps_position {
#---------------------------------------
TIMEOUT=20 # Time between status of GPS searches
echo ""
while [ ${LOCK:-0} -eq 0 ]; do
 printf " - Searching for your GPS position..\n"
 COORDINATE=$(timeout ${TIMEOUT} gpspipe -w -n 10 | jq -r '.lon, .lat'|awk 'ORS=NR%2?FS:RS' | grep "[[:digit:]]" | tail -1)
 if [ ! -z "${COORDINATE}" ]; then
  LOCK=1
 fi
done
 LAT_RAW=$(echo ${COORDINATE}|awk '{print $1}')
 LON_RAW=$(echo ${COORDINATE}|awk '{print $2}')
 LAT=$(printf "%.8f" "${LAT_RAW}")
 LON=$(printf "%.8f" "${LON_RAW}")
 if [ -z "${LAT}" -o -z "${LON}" ]; then 
  printf "\n ### ERROR - One of the coordinates (LAT/LONG) is 0 - please try again\n\n"
  exit
 fi
 printf "\n Found position LAT: %f LON %f\n\n" "${LAT:-0}" "${LON:-0}"
}
#---------------------------------------
function download_gsm_tower_data {
#---------------------------------------
 printf " - Downloading GSM towerdata from ${RADIUS} meters around this location..\n"
 ${WGET} --connect-timeout=30 -q "https://mastedatabasen.dk/Master/antenner/${LON},${LAT},${RADIUS}.json" -O ${TOWER_DATA_FILE}
 if [ $? -ne 0 ]; then
  printf "\n ### ERROR - An unknown error occured during the download of data!\n\n"
  exit
 fi
 if [ ! -f ${TOWER_DATA_FILE} ]; then
  printf "\n ### ERROR - The celltower data download to the file ${TOWER_DATA_FILE} failed!\n\n"
  exit
 fi
}
#--------------------------------------------------------------------
function convert_gsm_data_to_crocodile_format {
#--------------------------------------------------------------------
 if [ ! -s ${TOWER_DATA_FILE} ]; then 
  printf " - ### WARNING - The downloaded file containing the celltower data ( ${TOWER_DATA_FILE} ) was not found!\n"
  download_data 
 fi
 printf " - Parsing JSON data and extracting the GPS coordinates...\n\n"
 ${JQ} . ${TOWER_DATA_FILE}|egrep -e '"bredde"|"laengde"'|awk 'ORS=NR%2?FS:RS'|cut -d '"' -f 4,8|tr '"' ','|sort -n|uniq|awk '{print $1",Manual"}' > ${TOWER_DATA_GPS_COORDINATES_FILE}
 COUNT_TOWERS=$(cat ${TOWER_DATA_GPS_COORDINATES_FILE}|wc -l)
}
#--------------------------------------------------------------------
function import_data {
#--------------------------------------------------------------------
if [ ${COUNT_TOWERS:-0} -eq 0 ]; then 
 printf "\n ### ERROR - No celltower data found !\n\n"
else
 if [ -z "${DATABASE}" ]; then 
  select_database
 fi
 printf " Importing ${COUNT_TOWERS} celltower GPS coordinates in to the database \"${DATABASE}\":\n\n"
 cd ${SOURCE_DIRECTORY_FOR_CROCODILEHUNTER}
 ${PYTHON3} ${IMPORT_GPSDATA_SCRIPT} ${DATABASE} ${TOWER_DATA_GPS_COORDINATES_FILE} |sed -e "s/added/ added/"|sed -e "s/rejected/ rejected/"
fi
}
#--------------------------------------------------------------------
# MAIN
#--------------------------------------------------------------------
select_database
ask_for_download_of_tower_data
if [ ${RADIUS:-0} -ne 0 ]; then 
 initialize_gps
 get_current_gps_position 
 download_gsm_tower_data
 convert_gsm_data_to_crocodile_format
 import_data
fi
printf "\n Done\n\n"
