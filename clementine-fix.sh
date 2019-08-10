#!/bin/bash
# TODO: remove missing songs from playlist?

sqlite3 ~/.config/Clementine/clementine.db <<< "
-- Remove archived songs from the db, since they don't seem to be removed on a full library rescan
delete from songs WHERE filename like '%archive-link%';

-- Fix errors like 'Database: row 51 missing from index idx_filename'
DROP INDEX idx_filename;
CREATE INDEX idx_filename ON songs (filename);
"
