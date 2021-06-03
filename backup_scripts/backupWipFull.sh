#!/bin/sh

rsync -rltDOz --progress --include='*.RPP' --include='*.rpp' --include='*.wav' --include='*/' --exclude='*' '/Users/alex/Documents/REAPER Media/WIP/' diskstation:"'/volume1/Öffentlich/Audio Production/WIP'" --progress
