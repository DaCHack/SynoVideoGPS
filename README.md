# SynoVideoGPS
Brings Videos with GPS metadata to the Photo Station Map View

Tested on DS216play with DSM 6.2.2-24922 Update 4

How to bring GPS metadata into the PhotoStation database
-------------
- Place script in convenient location on one of your Synology Diskstation Volumes
- Run the script from a directory that you want to scan
- Run the script: `sh SynoVideoGPS.sh [YourDSMUserPassword]`

How to show videos with GPS data on map
-------------
You need to patch some files of the PhotoStation API in order to show videos on the map.
The included patch fixes videos not being shown on the web interface as well as the DS Photo App.
Unfortunately, Synology has no patch binary to apply it. Instead you need to apply it locally and upload the adapted files:
- `/volumeN/@appstore/PhotoStation/photo/webapi/file.php` 
- `/volumeN/@appstore/PhotoStation/photo/include/file.php`

Tips
-------------
- Install ffmpeg version from Community Repository to enable better Metadata recognition

Credits
-------------
Thanks to flingo64 for his support and his PhotoStation-Upload-Lr-Plugin for inspiration
