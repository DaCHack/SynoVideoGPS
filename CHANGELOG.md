SynoVideoGPS
======================

Version 0.1.5
-------------
- Take directory as 2nd parameter to be able to use the script via the DSM task scheduler
- Included a 1sec sleep after API call to give the indexing deamon some time to react (should improve indexing quality)
- Minor clean-ups of code

Version 0.1.4
-------------
- Account upper/lowercase file extensions
- Minor clean-ups of code

Version 0.1.3
-------------
- Optimized ffmpeg version check
- Fixed identification of absolute path for album ID

Version 0.1.2
-------------
- Minor fixes
- Added version number to code

Version 0.1.1
-------------
- Use community repository ffmpeg if available, fallback on built-in version if not
- Fix progress counter
- Remove ffmetadata parameter
- Clean-up cookie file after scan

Version 0.1.0
-------------
- Initial commit, seems to work fine but not for iPhone Videos yet
