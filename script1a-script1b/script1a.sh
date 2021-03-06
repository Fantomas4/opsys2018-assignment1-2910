#!/bin/bash

webpage_input_dir="$1"
webpages_queue_dir="./webpages_queue"

# Load all the webpage entries from the webpages_input file to an array
webpages_input_array=()

while IFS= read -r input_url
do	
	# ${input_url:0:1} expands to the substring starting at position 
	# 0 of length 1 (gives us the first character of the line)
	if [ "${input_url:0:1}" != "#" ]; then
		webpages_input_array+=("$input_url")
	fi
	
done < $webpage_input_dir

# Check if the webpages_queue.txt file exists in the webpages_queue_dir directory.
# If it doesn't, then create it.
if [ ! -f "$webpages_queue_dir" ]; then
    #echo "File not found!"
	touch webpages_queue
fi


# Load all the webpage entries from the webpages_queue file to an array
initial_webpages_queue_array=()

while IFS= read -r file_entry
do
	initial_webpages_queue_array+=("$file_entry")
	
done < $webpages_queue_dir

# final_webpages_queue_array will be used to store the refreshed and up-to-date
# data of the initial entries saved in initial_webpages_queue_array.
final_webpages_queue_array=()

# Iterate through all the webpage entries of the webpages_input_array,
# checking the webpages one by one

for input_url in "${webpages_input_array[@]}"
do
	
	# Check whether the given url already exists in the initial_webpages_queue_array
	found_url=0
	
	for queue_entry in "${initial_webpages_queue_array[@]}"
	do
		# get the saved webpage url, md5sum and status seperately
		entry_data=($queue_entry)
		queue_url=${entry_data[0]}
		url_md5sum=${entry_data[1]}
		url_status=${entry_data[2]}
		
		if [ "$input_url" = "$queue_url" ]; then
			# Found the target url in the url_queue"
			#echo "Found the target url in the url_queue"
			found_url=1
			
			# Check if the target url is reachable
			# 0 stands for true, 1 for false
			target_reachable=0
			curl $input_url -s -f -o /dev/null || target_reachable=1
			
			if [ $target_reachable -eq 0 ]; then
				# target url was found to be reachable!
				
				current_status="REACHABLE"
				
				# *** Check the webpage for changes ***
				# Download the currect webpage's md5sum and compare it 
				# to the stored md5sum for this webpage.
				current_md5sum=($(wget -q -O - $input_url | md5sum))
				
				
				if [ "$url_md5sum" != "$current_md5sum" ] || [ "$url_status" == "UNREACHABLE" -a "$current_status" == "REACHABLE" ]; then
					# the webpage HAS changed
					# the webpage's md5sum we retrieved from the file is different compared to the one we generated now, so we conclude the webpage has changed
					# or
					# target was saved as UNREACHABLE, but during the last check was found to be REACHABLE, so we assume the webpage has changed

					#echo "Detected changes in the given webpage:"
					echo $queue_url
					
					# add the changed webpage's url and md5sum as a new entry to the final_webpages_queue_array
					# (update the webpage's md5sum number)
					final_webpages_queue_array+=("$input_url $current_md5sum $current_status")
				
				else 
					# the webpage has not changed, so we simply add it to our final_webpages_queue_array
					final_webpages_queue_array+=("$input_url $url_md5sum $url_status")
			
				fi
				
			
			else
				# target url was found to be unreachable
				# print the "FAILED" message for the current url and
				# add the unreachable webpage's url and (old) md5sum as a new entry to the final_webpages_queue_array
				echo "$input_url FAILED" >&2
				current_status="UNREACHABLE"
				final_webpages_queue_array+=("$input_url $url_md5sum $current_status")
				
			fi

				
		fi
		
	done
	
	if [ $found_url = 0 ]; then
		# Target url was NOT found in the url_queue
		#echo "Target url was NOT found in the url_queue"
		
		# Check if the target url is reachable
		# 0 stands for true, 1 for false
		target_reachable=0
		curl $input_url -s -f -o /dev/null || target_reachable=1
		
		if [ $target_reachable -eq 0 ]; then
			# target url was found to be reachable!
			
			# generate the webpage's md5sum
			url_md5sum=($(wget -q -O - $input_url | md5sum))
			
			# status indicates whether we were able to reach the webpage during our last attempt
			status="REACHABLE"

			# add the webpage's url and md5sum as a new entry to the final_webpages_queue_array
			final_webpages_queue_array+=("$input_url $url_md5sum $status")

			echo "$input_url INIT"
		else
			# target url was found to be unreachable
			echo "$input_url FAILED" >&2
			
			# status indicates whether we were able to reach the webpage during our last attempt
			status="UNREACHABLE"
			
			url_md5sum="------------------"
			
			# add the webpage's url and (empty) md5sum as a new entry to the final_webpages_queue_array
			final_webpages_queue_array+=("$input_url $url_md5sum $status")
			
		fi

	fi
	
done

# Empty the webpages_queue file
> $webpages_queue_dir

# Save the current initial_webpages_queue_array state to the webpages_queue file
for queue_entry in "${final_webpages_queue_array[@]}"
do

	echo $queue_entry >> $webpages_queue_dir

done
















