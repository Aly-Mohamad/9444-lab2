#!/bin/bash

dir="$1"
mal_dir="$2"

ls -l "$dir" > directory-info.last


FILE="directory-info.new"

if [ ! -f "$FILE" ]; then
	echo "created"
	touch "$FILE"
fi


if cmp -s directory-info.new directory-info.last; then
	echo "Same"
else
	echo "Changed"

	for file in "$dir"/*; do
		if [ ! -f "$file" ]; then
			continue
		fi

		whitelist_name=$(basename "$file")
		if [ -f ".whitelist" ] && grep -Fxq "$whitelist_name" ".whitelist"; then
			echo "$file is whitelisted, skipping"
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

			echo "$file is malicious and it is DELETED"

			cp "$file" "$mal_dir/$filename"
			rm "$file"
		fi
	done

		cp directory-info.new directory-info.last 
	fi

ls -l "$dir" > directory-info.new
