#!/usr/bin/env bash

echo "DELETE FROM songs WHERE filename like '%archive-link%' AND unavailable = 0;" | sqlite3 "$HOME/.config/Clementine/clementine.db"
