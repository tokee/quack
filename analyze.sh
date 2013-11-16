#!/bin/bash

#
# Statistical helper functions for greyscale images.
#
# Requirements: ImageMagick's identify and convert
#

# Input: image
# Sample: foo.png
# Produces foo.identify is not already existing.
function im_identify() {
    local SRC="$1"
 
    local IDENTIFY=${SRC%%.*}.identify
    if [ -f "$IDENTIFY" ]; then
        return
    fi
    # We do the TIFF-conversion to force greyscale
    local TMP=`mktemp`.tif
    convert "$SRC" -colorspace gray "$TMP"
    identify -verbose "$TMP" > "$IDENTIFY"
    rm "$TMP"
}

# Produces a histogram over greyscale intensities in the given image
# Input: image height log
# Sample: foo.jpg 200 true
# Output: foo.png (256 x height pixels) with the histogram
function histogram() {
    local SRC="$1"
    local HEIGHT=$2
    local LOG=$3

    im_identify "$SRC"
    local IDENTIFY=${SRC%%.*}.identify
    local DEST=${SRC%%.*}.histogram.png
    # Convert      
    #   78085: (  0,  0,  0) #000000 black
    #    3410: (  1,  1,  1) #010101 rgb(1,1,1)
    # into
    # 0 78085
    # 1 3410
    GREYS=`cat "$IDENTIFY" | grep -A 9999 "  Histogram:" | grep -o " \\+[0-9]\\+: ( *[0-9]\\+, *[0-9]\\+, *[0-9]\\+)" | sed 's/ \\+\\([0-9]\\+\\): ( *\\([0-9]\\+\\).\\+/\\2 \\1/g'`
    
    # Find lowest and highest for both intensity and count
    local MIN_GREY=255
    local MAX_GREY=0
    local MIN_COUNT=9999999
    local MAX_COUNT=0

    local SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")
    while IFS= read -r L
    do
        local GREY=`echo "$L" | cut -d\  -f1`
        local COUNT=`echo "$L" | cut -d\  -f2`
        if [ $MIN_GREY -gt $GREY ]; then
            local MIN_GREY=$GREY
        fi
        if [ $MAX_GREY -lt $GREY ]; then
            local MAX_GREY=$GREY
        fi
        if [ $MIN_COUNT -gt $COUNT ]; then
            local MIN_COUNT=$COUNT
        fi
        if [ $MAX_COUNT -lt $COUNT ]; then
            local MAX_COUNT=$COUNT
        fi
    done <<< "$GREYS"
    IFS=$SAVEIFS
#    echo "Grey: $MIN_GREY $MAX_GREY  count: $MIN_COUNT $MAX_COUNT"

    # Let SCALE map all counts from 0 to 1
    if [ ".true" == ".$LOG" ]; then
        local SCALE=`echo "scale=10;1/l($MAX_COUNT)" | bc -l`
    else
        local SCALE=`echo "scale=10;1/$MAX_COUNT" | bc -l`
    fi

    # We create a PGM-file with the extracted greyscale statistics
    # as a histogram. The PGM is sideways because it is easier
    # http://netpbm.sourceforge.net/doc/pgm.html
    local HTMP=`mktemp`.pgm
    if [ "true" == "$LOG" ]; then
        local NONE=1
    else
        local NONE=0
    fi

    echo "P5 $HEIGHT 256 255" > $HTMP
    for G in `seq 0 255`; do
        local COUNT=`echo "$GREYS" | grep "^$G " | sed 's/[0-9]\\+ \\([0-9]\\+\\)/\\1/g'`
        if [ "." == ".$COUNT" ]; then
            local COUNT=$NONE
        fi
        if [ "true" == "$LOG" ]; then
            local PIXELS=`echo "scale=10;l($COUNT)/l(10)*$SCALE*$HEIGHT" | bc -l`
        else 
            local PIXELS=`echo "scale=10;$COUNT*$SCALE*$HEIGHT" | bc -l`
        fi
        # /1 due to funky bc scale not being applied if nothing is done
        local PIXELS=`echo "scale=0;$PIXELS/1" | bc -l`

        for P in `seq 0 $((HEIGHT-1))`; do
            if [ $P -le $PIXELS ]; then
                echo -n -e \\x0 >> $HTMP
            else 
                echo -n -e \\xff >> $HTMP
            fi
        done
        echo "$G $COUNT $PIXELS"
    done
    convert -rotate 270 $HTMP "$DEST"
    rm $HTMP
}

#histogram $1 200 false
