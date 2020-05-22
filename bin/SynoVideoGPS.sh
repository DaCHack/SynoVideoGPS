#!/bin/bash
#set -x errexit

# SynoVideoGPS Version 0.2.0

ds_ip="localhost"											# change to IP adress if localhost does not work
script_dir=$(dirname "$0")									# all relevant external data is in the script directory, we should know it
cookiesFn="/tmp/cookies.txt"
gpsDataBinFn="/tmp/gps-data.bin"
gpsDataJsonFn="/tmp/gps-data.json"
fileListFn="/tmp/filelist.txt"

ps_basedir=$( ls -d /volume?/photo | head -1 )
albumPath=$1														# provide absolute album path (relative to PhotoStation base directory) that should be scanned as first parameter (it is not relevant where on the volume the script is located)
dir="${ps_basedir}${albumPath}"


# Get user data
# If 2nd parameter is not set, assume the script is called via Cron Job an get data from config file
if [[ $2 = "" ]]; then
    myuser=$(awk -F "=" '/ps_username/ {print $2}' $script_dir/SynoVideoGPS.conf)
    myuser=$( echo $myuser | php -R 'echo urlencode($argn);')
    mypass=$(awk -F "=" '/ps_password/ {print $2}' $script_dir/SynoVideoGPS.conf)
    mypass=$( echo $mypass | php -R 'echo urlencode($argn);')
#Else, assume the script is called from shell and get password from parameter
else
	mypass=$( echo $2 | php -R 'echo urlencode($argn);')	# provide user password as second parameter to the script
	myuser=$(id -u -n)										# always use WebAPI as currently logged in user
fi

#Log into PS
url="http://${ds_ip}/photo/webapi/auth.php?api=SYNO.PhotoStation.Auth&method=login&version=1&username=$myuser&password=$mypass"
login_result=$( curl -c "$cookiesFn" "http://${ds_ip}/photo/webapi/auth.php?api=SYNO.PhotoStation.Auth&method=login&version=1&username=$myuser&password=$mypass" 2>&1 )
if [[ ! "$login_result" =~ .*sid.* ]]; then
  echo $url
  echo $login_result
	exit 1
fi
echo "Login successful. Cookie created..."

#Save gopro2json path (should always be in same directory as script)
gopro2json="$script_dir/gopro2json.bin"

#Check if community version of ffmpeg installed
ffmpeg_tool=$( ls /volume?/@appstore/ffmpeg/bin/ffmpeg | head -1 )
if [[ "$ffmpeg_tool" = "" ]];  then
	ffmpeg_tool=/bin/ffmpeg
fi

#Scan through subdirectories and filter out thumbnails
counter=0
#total=$( find "$dir" -type f -print | grep -v "eaDir" | wc -l )
find "$dir" -type f -not -path "*/@eaDir*" > $fileListFn
total=$(cat $fileListFn | wc -l)

#find "$dir" -type f -print0 | while IFS= read -r -d '' current_path
while [ -s $fileListFn ]
do

  #Save first line and work with it after it is removed from the file (this way the file gets empty and the loop can exit)
  current_path=$( head -1 $fileListFn )
  sed -i '1d' $fileListFn

	#Prepare progress info and file type information
	((counter=counter+1))
	((progress=(counter*100/total)))

	file=$(basename -- "$current_path")
	file_extension=$( echo "${file##*.}" | awk '{print tolower($0)}' )

  #Get ffmpeg scan results for supported file types
  declare -A supported_types
  supported_types[mov]=1
  supported_types[mp4]=1

  if [[ ${supported_types[$file_extension]} ]]; then
    #Move this line out of the if-statement to get a progress output on each file scanned
	  echo -e "[${progress}%]\tScanning $current_path"
    ffmpeg_data=$( ${ffmpeg_tool} -i "${current_path}" 2>&1 )
  else
    #echo "Unsupported file type"
    continue
  fi

	#Check MOV files from iPhones
	if  [ "$file_extension" = "mov" ]; then
		geo_data=$( echo "$ffmpeg_data" | awk '/com.apple.quicktime.location.ISO6709/{print substr($2,1,length($2)-1)}' )

		# Extract GPS data from ffmpeg output
		GPS_latitude=$( echo $geo_data | awk -F"+|-" '{print substr($0,index($0,$2-1),1) $2}' )
		GPS_longitude=$( echo $geo_data | awk -F"+|-" '{print substr($0,index($0,$3-1),1) $3}' )

	#Check MP4 files from GoPro
	elif  [ "$file_extension" = "mp4" ]; then
		geo_data=$( echo "$ffmpeg_data" | awk '/location /{print substr($3,1,length($3)-1)}' )

    # If GPS data was easy to extract via metadata save it for next steps
		if [ ! "$geo_data" = "" ]; then
      # Extract GPS data from ffmpeg output
      GPS_latitude=$( echo $geo_data | awk -F"+|-" '{print substr($0,index($0,$2-1),1) $2}' )
      GPS_longitude=$( echo $geo_data | awk -F"+|-" '{print substr($0,index($0,$3-1),1) $3}' )
    else
      #Otherwise, check if we can find more data in the GoPro specific data stream
			echo -n "No GPS in header. "
      gopro_indicator=$( echo "$ffmpeg_data" | grep -c "GoPro" )

			#If gopro2json is installed and we have a GoPro video, do an additional scan of GoPro metadata stream
			if [ -f "${gopro2json}" ] && [ $gopro_indicator -gt 0 ]; then

			  echo -n "Using gopro2json. "

				#Extract metadata stream to a temp file
				tabulator=$(echo -e "\t")
    		output_metadata_creation=$( ${ffmpeg_tool} -y -i ${current_path} -codec copy -map 0:m:handler_name:"${tabulator}GoPro MET" -f rawvideo $gpsDataBinFn 2>&1 )

				#Get JSON from metadata stream
				output_JSON_creation=$( "${gopro2json}" -i $gpsDataBinFn -o $gpsDataJsonFn 2>&1 )
				if [ $? -eq 0 ]; then
				    echo "JSON created."
				else
				    echo "Error creating JSON."
				    echo "$output_metadata_creation"
            echo "$output_JSON_creation"
				    exit
				fi

        #Without parsing JSON we can only get the first signal which often is incorrect
				#GPS_latitude=$( head -c 50 $gpsDataJsonFn | awk -F":|," '{print $3}' )
				#GPS_longitude=$( head -c 50 $gpsDataJsonFn | awk -F":|," '{print $5}' )

        #Get most recent GPS coordinates (most probably the most reliable ones)
        GPS_latitude=$( echo $gpsDataJsonFn | php -R '
          $str = file_get_contents($argn);
          $json = json_decode($str, true);
          $index = count($json[data])-1;
          echo print_r($json[data][$index][lat], true);
          ' )
        GPS_longitude=$( echo $gpsDataJsonFn | php -R '
          $str = file_get_contents($argn);
          $json = json_decode($str, true);
          $index = count($json[data])-1;
          echo print_r($json[data][$index][lon], true);
          ' )
        echo -n " ${GPS_latitude} "
        echo -n " ${GPS_longitude} "

				#Clean-up and remove the temp files
				rm -f $gpsDataBinFn
				rm -f $gpsDataJsonFn

			else
        echo "No GoPro video or gopro2json tool not available. "
			fi

		fi

	else
		#Skip all other file types
		continue
	fi

	# URLencode GPS data and remove "+" signs (try to fix iPhone not showing GPS data for videos)
	GPS_latitude=$( echo "$GPS_latitude" | sed 's/+//g' | sed 's/-/%2D/g' | sed 's/\./%2E/g' )
	GPS_longitude=$( echo "$GPS_longitude" | sed 's/+//g' | sed 's/-/%2D/g' | sed 's/\./%2E/g' )

	#Skip if no GPS data found
	if [[ ! "$GPS_latitude" =~ .*%2E.* ]]; then
    echo "No GPS data found"
    echo ""
		continue
	fi
	if [[ ! "$GPS_longitude" =~ .*%2E.* ]]; then
    echo "No GPS data found"
    echo ""
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

	edit_result_token=$(curl -b "$cookiesFn" ${url} 2>&1)

	if [[ "$edit_result_token" = *"error"* ]]; then
		echo "Error: Could not save GPS data"
		exit 1
	fi
	echo "GPS data saved"
  echo ""

  #Clean up key variables for next iteration
  geo_data=""
  GPS_latitude=""
  GPS_longitude=""

	#Give syno_index deamon some time (hoping more files are reliably indexed)
	sleep 1

done

#Clean up and remove filelist.txt and cookies.txt
rm -f "$fileListFn" "$cookiesFn"
