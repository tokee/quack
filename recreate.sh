#!/bin/bash

#
# Requires jpegtran with October 2012 patch.
# Download latest source from http://www.ijg.org/files/ 
# Download http://sylvana.net/jpegcrop/droppatch.v9.tar.gz
#
# tar -xzovf jpegsrc.v9.tar.gz
# tar -xzovf droppatch.v9.tar.gz
# cd jpeg-9
# ./configure
# sudo make install
# sudo echo "/usr/local/lib/" >> /etc/ld.so.conf 
# sudo ldconfig
#

SOURCE=$1

if [ "." == ".$SOURCE" ]; then
    echo "Usage: ./recreate tilefolder"
    exit 2
fi
if [ ! -d "$SOURCE" ]; then
    echo "The folder '$SOURCE' could not be located"
    exit 2
fi

TILE_FOLDER=`du ${SOURCE}/* | sort -n | tail -n 1 | sed 's/[0-9]\\+[[:space:]]\\+\\(s\\)/\\1/g'`
if [ "." == ".$TILE_FOLDER" ]; then
    echo "Unable to locate proper sub-filder with tiles in '$SOURCE'"
    exit 2
fi

ROWS=`ls ${TILE_FOLDER}/0_* | wc -l`
COLUMNS=`ls ${TILE_FOLDER}/*_0.* | wc -l`

echo "$TILE_FOLDER $ROWS"