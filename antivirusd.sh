#!/bin/bash

dir="$1"
mal_dir="$2"
interval_sec="$3"

ls -l "$dir" > directory-info.last

while true; do
	sleep "$interval_sec"

	ls -l "$dir" > directory-info.new

	if cmp -s directory-info.new directory-info.last; then
		echo "Same"
	else
		echo "Changed"

		for file in "$dir"/*; do
           		if [ ! -f "$file" ]; then
				continue
			fi

			malicious=false

            		case "$file" in
                		*.exe|*.bat|*.vbs|*.scr|*.ps1)
                    			malicious=true
                    			;;
            		esac

           	 	if grep -qiE 'virus|trojan|malware|worm|ransomware' "$file"; then
				malicious=true
           		fi

			if [ "$malicious" = true ]; then
				filename=$(basename "$file")

				echo "$file is malicious and it is deleted"

				cp "$file" "$mal_dir/$filename"
				rm "$file"
			fi
       		 done

		cp directory-info.new directory-info.last 
	fi
done

