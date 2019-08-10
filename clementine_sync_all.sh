#!/bin/bash
# list tables:  .tables
# list schema:  .schema [table]
# help:         .help

# TODO: can't handle "+" in the filenames (Of Monsters and Men/Sparks + Glowsticks/Little Talks)

# config options
# no trailing slashes
MUSIC_DIR="Music"
PLAYLIST_DIR="Playlists"
TMP_DIR="/tmp/clem_sync"
TARGET_BASE_REL_TO_MNT="Audio"
TARGET_MNT="$1"
RSYNC_DIR="$TARGET_MNT/$TARGET_BASE_REL_TO_MNT"
shift
SSH_ARGS="$1"
if [[ "$SSH_ARGS" == "-ssh"* ]]; then
    # compression + ssh
	SSH_ARGS=( "-e" "${SSH_ARGS:1}" )
	shift
else
	SSH_ARGS=()
	if [[ ! -d "$TARGET_MNT" ]]; then
		echo "Target directory $TARGET_MNT does not exist. Is the target mounted?"
		exit 1
	fi

	if [[ ! -d "$RSYNC_DIR" ]]; then
		mkdir -p "$RSYNC_DIR"
	fi
fi
PLAYLISTS=("$@")

function urldecode() {
    # urldecode <string>
    #local url_encoded="${@//+/ }"
    local url_encoded="${@/// }"
    printf '%b' "${url_encoded//%/\\x}"
}
    
CFG_DIR="$HOME/.config/Clementine"
DB="clementine.db"
MUSIC_BASE_REL_TO_PLAYLISTS="../Music"
INCLUDE_LIST="$TMP_DIR/include.txt"

# all music is relative to this directory
# trailing slash
#BASE_DIR="/media/Files/Media/Audio/Music/"
BASE_DIR="$(realpath "$(dirname $0)")/Music/"

# prefix to copy (don't copy streams)
PREFIX="file://"

# create a clean tmp environment
rm -rf "$TMP_DIR"
mkdir "$TMP_DIR"
cd "$TMP_DIR"
ln -s "$BASE_DIR" "$MUSIC_DIR"
mkdir "$PLAYLIST_DIR"

echo "creating playlists..."
I=0
while [[ $I -lt ${#PLAYLISTS[@]} ]]; do
    PLAYLIST="${PLAYLISTS[$I]}"

    PLAYLIST_TXT="$(echo -e "#EXTM3U\n")"

    #ENCODED_FILES=( $(sqlite3 "$CFG_DIR/$DB" <<< "
    #    SELECT s.filename 
    #    FROM playlists p 
    #    INNER JOIN playlist_items pi on p.ROWID == pi.playlist 
    #    INNER JOIN songs s on s.ROWID == pi.library_id 
    #    WHERE p.name == '$PLAYLIST';
    #    " | grep "^$PREFIX" | sed -r "s#^$PREFIX##") )
    
    # Create the query
    ENCODED_FILES=""
    QUERY=""
    if [[ "$PLAYLIST" == Smart_* ]]; then
        PLAYLIST="$(echo "$PLAYLIST" | sed -r 's/^Smart_//')"
        if [[ "$PLAYLIST" == "All" ]]; then
            QUERY="SELECT s.filename 
                   FROM songs s
                   WHERE s.unavailable = 0;"
        elif [[ "$PLAYLIST" == "All Music" ]]; then
            QUERY="SELECT s.filename 
                   FROM songs s 
                   WHERE artist != 'Brian Regan'
                   AND s.unavailable = 0;"
        elif [[ "$PLAYLIST" == Newest* ]]; then
            N="$(echo "$PLAYLIST" | grep -o "[0-9]*")"
            [[ -z "$N" || "$N" -le 0 ]] && continue

            QUERY="SELECT s.filename 
                   FROM songs s
                   WHERE s.unavailable = 0
                   ORDER BY ROWID DESC 
                   LIMIT $N;"
        fi
    else
        # Don't filter on unavailable songs, since this tells us the playlist should be modified in clementine
        QUERY="SELECT s.filename 
               FROM playlists p 
               INNER JOIN playlist_items pi on p.ROWID == pi.playlist 
               INNER JOIN songs s on s.ROWID == pi.library_id 
               WHERE p.name == '$PLAYLIST';"
    fi
        
    PLAYLIST_FILE="$PLAYLIST_DIR/$PLAYLIST.m3u"

    # Grab the file list
    # Filter by the file/stream prefix and remove it
    ENCODED_FILES=( $(sqlite3 "$CFG_DIR/$DB" <<< "$QUERY" | sed -r -e "s#^$PREFIX##" -e t -e d) )

    J=0
    while [[ $J -lt ${#ENCODED_FILES[@]} ]]; do
        # decode one by one and make the files relative to the base
        FILE="$(urldecode "${ENCODED_FILES[$J]}" | sed -r "s#$BASE_DIR##")"
		J=$(($J+1))

		#[[ -e "$MUSIC_DIR/$FILE" ]] || (echo "Suggest removing file '$FILE' from 'PLAYLIST'" && continue)
		#[[ -e "$MUSIC_DIR/$FILE" ]] || (continue) 
		if [[ ! -e "$MUSIC_DIR/$FILE" ]]; then
			echo "WARNING: '$FILE' from '$PLAYLIST' does not exist"
			continue
		fi

        PLAYLIST_TXT="$(echo -e "$PLAYLIST_TXT\n$MUSIC_BASE_REL_TO_PLAYLISTS/$FILE")"
        
        # encode it for the shell
        #FILE="$(printf "%q" "$FILE")"
        echo "$MUSIC_DIR/$FILE" >> "$INCLUDE_LIST"
    done

    echo "$PLAYLIST_TXT" > "$PLAYLIST_FILE"
    echo "$PLAYLIST_FILE" >> "$INCLUDE_LIST"

    I=$(($I+1))
done

echo "syncing...."
echo "Running: rsync -aiv --relative --delete-excluded --no-perms --no-times --size-only --progress -L --prune-empty-dirs --include='/**/' --files-from=\"$INCLUDE_LIST\" --exclude='*' \"${SSH_ARGS[@]}\" . \"$RSYNC_DIR\""
rsync -aiv --relative --delete-excluded --no-perms --no-times --size-only --progress -L --prune-empty-dirs --include='/**/' --include-from="$INCLUDE_LIST" --exclude='*' "${SSH_ARGS[@]}" . "$RSYNC_DIR"

# clean the environment
rm -rf "$TMP_DIR"
