# crocodilehunter_dk_tower
Import danish celltowers to eff.org's crocodile hunter (https://github.com/EFForg/crocodilehunter)

root@fitlet:~/source/Crocodilehunter# ./import_towers_dk.sh

       ^             ^
       |             |
       +            THE
       |          DANISH
       A         CELLTOWER 
      ===       GPS POSITION 
     /EEE\       RETRIEVER 
    //EEE\\       SCRIPT 
 __//_____\\___    2000

 - Checking for existence of needed utilities..
 - Checking if MySQL is running..
 - ### WARNING - MySQL not running - attempting to start it..
 - Retrieving a list of used databases..

 Found 2 database(s)

1) dubex
2) home

  Please select the database you want to import the  celltower(s) coordinates in to: 2

 - Database selected: "home"
 - Downloading the data from mastedatabasen.dk..
 - Parsing JSON data and extracting the GPS coordinates...
 - Found 9349 celltower GPS coordinates..
 - Importing data in to the database "home"..

 added 0 known towers
 rejected 9349 duplicate towers

 Done
