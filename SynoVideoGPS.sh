#!/bin/bash
#set -x errexit

# SynoVideoGPS Version 0.1.5


mypass=$( echo $1 | php -R 'echo urlencode($argn);')	# provide user password as first parameter to the script
dir=$2							# provide absolute path to album that should be scanned as second parameter (it is not relevant where on the volume the script is located)
myuser=$USER						# always use WebAPI as currently logged in user
ds_ip="localhost"					# change to IP adress if localhost does not work

#Enter album to be scanned and set $dir to local directory
cd "$dir"
dir="."

#Log into PS
login_token=$( curl -c cookies.txt "http://${ds_ip}/photo/webapi/auth.php?api=SYNO.PhotoStation.Auth&method=login&version=1&username=$myuser&password=$mypass" 2>&1 )
if [[ ! "$login_token" =~ .*sid.* ]]; then
	echo "Login Error."
	exit 1
fi
echo "Login successful. Cookie created..."

#Check if community version of ffmpeg installed
ffmpeg_tool=$( ls /volume?/@appstore/ffmpeg/bin/ffmpeg | head -1 )
if [[ "$ffmpeg_tool" = "" ]];  then
	ffmpeg_tool=/bin/ffmpeg
fi

#Scan through subdirectories
counter=0
total=$( find "$dir" -type f -print | grep -v "eaDir" | wc -l )

find "$dir" -type f -print0 | while IFS= read -r -d '' current_path
do

	#Do nothing for Thumbnails etc.
	if [[ $current_path = *"eaDir"* ]]; then
		continue
	fi

	#Prepare progress info
	((counter=counter+1))
	((progress=(counter*100/total)))

	#Continue depending on file type
	echo -e "[${progress}%]\tScanning $current_path"
	file=$(basename -- "$current_path")
	file_extension=$( echo "${file##*.}" | awk '{print tolower($0)}' )

	#Check MOV files from iPhones
	if  [ "$file_extension" = "mov" ]; then
		geo_data=$( ${ffmpeg_tool} -i "${current_path}" -f ffmetadata 2>&1 | awk '/com.apple.quicktime.location.ISO6709/{print substr($2,1,length($2)-1)}' )
	
	#Check MP4 files from GoPro
	elif  [ "$file_extension" = "mp4" ]; then
		geo_data=$( ${ffmpeg_tool} -i "${current_path}" -f ffmetadata 2>&1 | awk '/location /{print substr($3,1,length($3)-1)}' )
	else
		#Skip all other file types
		continue
	fi

	# Extract GPS data from ffmpeg output
	GPS_latitude=$( echo $geo_data | awk -F"+|-" '{print substr($0,index($0,$2-1),1) $2}' )
	GPS_longitude=$( echo $geo_data | awk -F"+|-" '{print substr($0,index($0,$3-1),1) $3}' )

	#Remove leading zeros in coordinates (thought it would be relevant for Apple tags but obviously it is not needed. keeping it for a while)
	#GPS_latitude=$( echo $GPS_latitude | sed -E 's/([+-])0+/\1/g' )
	#GPS_longitude=$( echo $GPS_longitude | sed -E 's/([+-])0+/\1/g' )

	# URLencode GPS data and remove + signs (try to fix iPhone not showing GPS data for videos)
	GPS_latitude=$( echo "$GPS_latitude" | sed 's/+//g' | sed 's/-/%2D/g' | sed 's/\./%2E/g' )
	GPS_longitude=$( echo "$GPS_longitude" | sed 's/+//g' | sed 's/-/%2D/g' | sed 's/\./%2E/g' )

	#Skip if no GPS data found
	if [[ $GPS_latitude != *"%2E"* ]]; then
		continue
	fi
	if [[ $GPS_longitude != *"%2E"* ]]; then
		continue
	fi

	#Print GPS data if something is found
	echo -n " ${geo_data} "
	echo -n " ${GPS_latitude} "
	echo -n " ${GPS_longitude} "

	#Get video path (relative to /photo/) -> cut "/volumeX/photo/"
	absolute_path=$(realpath "${current_path}")
	video_path=$(dirname "${absolute_path}" | cut -d'/' -f 4- )

	#Build video ID
	#video_<AlbumPathInHex>_<PhotoPathInHex>
	album_SubID=$(echo -n "${video_path}" | od -An -t x1 | tr -d '\n ')
	video_SubID=$(echo -n "$file" | od -An -t x1 | tr -d '\n ')
	video_id=$( echo "video_${album_SubID}_${video_SubID}")

	#Save Location to video
	url="http://${ds_ip}/photo/webapi/photo.php?api=SYNO.PhotoStation.Photo&method=edit&version=1&id=${video_id}&gps_lat=${GPS_latitude}&gps_lng=${GPS_longitude}"

	edit_result_token=$(curl -b cookies.txt ${url} 2>&1)

	if [[ "$edit_result_token" = *"error"* ]]; then
		echo "Error: Could not save GPS data"
		exit 1
	fi
	echo "GPS data saved"

	#Give syno_index deamon some time (hoping more files are reliably indexed)
	sleep 1

done

#Clean up and remove cookies.txt
rm cookies.txt
