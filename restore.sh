#!/bin/bash

dir="$1"
mal_dir="$2"

while true; do
	if [ -z "$(ls -A "$mal_dir")" ]; then
    		echo "No malicious files to review."
		sleep 3
		continue
	fi

	files=("$mal_dir"/*)

	echo "Choose a file:"

	for i in "${!files[@]}"; do
    		echo "$((i + 1)). $(basename "${files[$i]}")"
	done

	read -p "> " choice

	selected_file="${files[$((choice - 1))]}"

	filename=$(basename "$selected_file")

	echo "You selected: $filename"

	echo "Choose operation:"
	echo "1. Restore $filename to $dir"
	echo "2. Permanently delete $filename"
	echo "3. Leave it and return"
	
	read choice
	if [ $choice -eq 1 ]; then
		cp "$selected_file" "$dir/$filename"
		rm "$selected_file"
		echo "Restored $filename to $dir."

		touch ".whitelist"
		if ! grep -Fxq "$filename" ".whitelist"; then
			echo "$filename" >> ".whitelist"
		fi
		echo "$filename added to whitelist"

	elif [ $choice -eq 2 ]; then
		rm "$selected_file"
		echo "$filename permanently deleted."
	else
		continue
	fi
done
