#!/bin/sh

rsync -rtm --include='*.RPP' --include='*.rpp' --include='*/' --exclude='*' '/Users/alex/Documents/REAPER Media/WIP' diskstation:"'/volume1/Öffentlich/Audio Production/WIP/project files'" --progress 
