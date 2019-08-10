#!/bin/bash
# Toggles Clementine's access to my archived music via a symbolic link. This allowes easy porting between the
# standard and archived libraries with easily on-demand isolation of archived audio

#TODO: handle quotes when printing?

PWD="$(realpath "$(dirname "$0")")"

cd "$PWD"

LINK="archive-link"
TARGET="archive"

if [[ -e "$LINK" ]]; then
	if [[ -L "$LINK" ]]; then
		echo "Removing symbolic link: '$LINK'"
		rm "$LINK"
	else
		echo "Object is not a symbolic link: '$LINK'"
		exit 1
	fi	
else
	if [[ -d "$TARGET" ]]; then
		echo "Creating symbolic link '$LINK' to target '$TARGET'"
		ln -s "$TARGET" "$LINK"
	else
		echo "Target is not a directory: '$TARGET'"
		exit 1
	fi
fi
