# SynoVideoGPS
Brings Videos with GPS metadata to the Photo Station Map View

Tested on DS216play with DSM 6.2.2-24922 Update 4

How to bring GPS information included in metadata into the PhotoStation database
-------------
- Place script in convenient location on one of your Synology Diskstation Volumes
- Run the script from a directory that you want to scan
- Run the script: `sh SynoVideoGPS.sh [YourDSMUserPassword]`

How to show videos with GPS data on map
-------------
You need to patch some files of the PhotoStation API in order to show videos on the map.
The included patch fixes videos not being shown on the web interface as well as the DS Photo App.
- Copy the patch file to /volumeX/@appstore/PhotoStation/photo/ and issue this command:
`patch -p0 < PhotoStation_VideosOnMap.patch`

Tips
-------------
- Install ffmpeg version from Community Repository to enable better Metadata recognition

Credits
-------------
Thanks to flingo64 for his support and his PhotoStation-Upload-Lr-Plugin for inspiration
