# SynoVideoGPS
Brings Videos with GPS metadata to the Photo Station Map View

Tested on DS216play with DSM 6.2.2-24922 Update 4

This is my first repository on Github so please excuse any misbehaviours that may certainly not be intentionally.
Also I only want to share my insights and cannot take responsibility for any harms to your data or devices.

How to bring GPS metadata into the PhotoStation database
-------------
PhotoStation does not scan videos for GPS metadata. Thus, you need to run a manual scan and provide PhotoStation with the results via an API call. The SynoVideoGPS script does that job for you.
- Place script in convenient location on one of your Synology Diskstation Volumes
- Run the script from a directory that you want to scan
- Run the script: `sh SynoVideoGPS.sh [YourDSMUserPassword]`

How to show videos with GPS data on map
-------------
You need to patch some files of the PhotoStation API in order to show videos on the map.
The included patch fixes videos not being shown on the web interface as well as the DS Photo App.
Unfortunately, Synology has no patch binary to apply it. Instead you need to apply it locally and upload the adapted files:
- `/volumeN/@appstore/PhotoStation/photo/webapi/photo.php`
- `/volumeN/@appstore/PhotoStation/photo/include/file.php`

Tips
-------------
- Install ffmpeg version from Community Repository to enable better Metadata recognition
- [Enable GPMD support](https://github.com/DaCapitalist/SynoVideoGPS/wiki/Enable-GPMD-support) to find even more videos with GPS data (GoPro only)
- After the script completed PhotoStation continues to index the new metadata. Please wait for the `postgres` and `synoindexplugind` processes to complete before the data will be visible in PhotoStation. As long as the indexing continues you will find the progresses on top of the list with significant CPU usage when you enter the command `top`

Credits
-------------
Thanks to flingo64 for his support and his PhotoStation-Upload-Lr-Plugin for inspiration
