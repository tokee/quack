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

# Input: tile_folder
# Output: ROWS, COLUMNS, TILE_SIZE, MARGIN, WIDTH, HEIGHT
resolve_tile_data() {
    local TILE_FOLDER=$1

    COLUMNS=`ls ${TILE_FOLDER}/0_* | wc -l`
    ROWS=`ls ${TILE_FOLDER}/*_0.* | wc -l`

    local FIRST=`ls ${TILE_FOLDER}/0_0.*`
    local IDENTIFY=`identify "$FIRST" | grep -o " [0-9]\+x[0-9]\\+ "`
    local IMAGE_WIDTH=`echo $IDENTIFY | head -n 1 | grep -o "[0-9]\+x" | grep -o "[0-9]\+"`
    TILE_SIZE=`echo "$IMAGE_WIDTH / 16 * 16" | bc`
    MARGIN=`echo "$IMAGE_WIDTH - $TILE_SIZE" | bc`

    local CM1=`echo "$COLUMNS - 1" | bc`
    local RM1=`echo "$ROWS - 1" | bc`
    local LAST=`ls ${TILE_FOLDER}/${RM1}_${CM1}.*`
    local IDENTIFY=`identify "$LAST" | grep -o " [0-9]\+x[0-9]\\+ "`
    local LAST_WIDTH=`echo $IDENTIFY | grep -o "[0-9]\+x" | head -n 1 | grep -o "[0-9]\+"`
    local LAST_HEIGHT=`echo $IDENTIFY | grep -o "x[0-9]\+" | head -n 1 | grep -o "[0-9]\+"`
    HEIGHT=`echo "($COLUMNS - 1) * $TILE_SIZE + $LAST_HEIGHT - $MARGIN" | bc`
    WIDTH=`echo "($ROWS - 1) * $TILE_SIZE + $LAST_WIDTH - $MARGIN" | bc`

    #echo "$TILE_FOLDER rows=$ROWS columns=$COLUMNS tile_size=$TILE_SIZE margin=$MARGIN full_image=${WIDTH}x${HEIGHT}"
}

resolve_tile_data $TILE_FOLDER
