#!/bin/bash

#
# Statistical helper functions for greyscale images.
#
# Requirements: ImageMagick's identify and convert
#

# If true, input files are assumed to be greyscale.
# If false, they are converted to greyscale before extracting statistics.
if [ "." == ".$ASSUME_GREY" ]; then
    ASSUME_GREY=true
fi

# TODO: Accept destination for identify-file as input

# Input: image
# Sample: foo.png
# Produces foo.identify if not already existing.
# Output: The name of the identity file
function im_identify() {
    local SRC="$1"

    local IDENTIFY=${SRC%%.*}.identify
    if [ -f "$IDENTIFY" ]; then
        echo "$IDENTIFY"
        return
    fi
    if [ "false" == "$ASSUME_GREY" ]; then
    # We do the TIFF-conversion to force greyscale
        local TMP=`mktemp`.tif
        convert "$SRC" -colorspace gray "$TMP"
        identify -verbose "$TMP" > "$IDENTIFY"
        rm "$TMP"
    else
        identify -verbose "$SRC" > "$IDENTIFY"
    fi
    echo "$IDENTIFY"
}

# TODO: Accept destination for grey-stats-file as input

# Input: image
# Sample: foo.png
# Produces foo.grey with $PIXELS $UNIQUE $FIRST_COUNT $PERCENT_FIRST $FIRST_GREY $LAST_COUNT $PERCENT_LAST $LAST_GREY
# Output: $PIXELS $UNIQUE $FIRST_COUNT $PERCENT_FIRST $FIRST_GREY $LAST_COUNT $PERCENT_LAST $LAST_GREY $ZEROES $HOLES
function grey_stats() {
    local SRC="$1"
    if [ ! -f "$SRC" ]; then
        echo "grey_stats: The file $SRC does not exist in `pwd`"
        return
    fi

    local IDENTIFY=$(im_identify "$SRC")
    local GREY=${SRC%%.*}.grey
    local INFO=`cat "$IDENTIFY"`
    # TODO: No good as the histogram data might be much less than 256
    local VALUES=`cat "$IDENTIFY" | grep -A 256 Histogram`
    if [ ! "." == ".`echo "$VALUES" | grep Colormap`" ]; then
        local VALUES=`echo "$VALUES" | grep -B 256 Colormap`
    fi        
    local RAW_VALUES=`echo "$VALUES" | grep "[0-9]\\+: ("`
#    local VALUES="$INFO"

    local SAVEIFS=$IFS
    IFS=$(echo -en "\n")
    
    local UNIQUE=`echo $RAW_VALUES | wc -l`

    local FIRST_COUNT=`echo $RAW_VALUES | head -n 1 | grep -o " [0-9]\\+:" | grep -o "[0-9]\\+"`
    local FIRST_GREY=`echo $RAW_VALUES | head -n 1 | grep -o " ([0-9 ,]*)" | sed 's/ //g'`
    
    local LAST_COUNT=`echo $RAW_VALUES | tail -n 1 | grep -o " [0-9]\\+:" | grep -o "[0-9]\\+"`
    local LAST_GREY=`echo $RAW_VALUES | tail -n 1 | grep -o " ([0-9 ,]*)" | sed 's/ //g'`

    local ZEROES=$((256-UNIQUE))
    local SPAN=$((LAST_GREY-FIRST_GREY+1))
    local EDGE=$((256-SPAN))
    local HOLES=$((ZEROES-EDGE))

    local SPIKE_COUNT=`echo $RAW_VALUES | sort -n | tail -n 1 | grep -o " [0-9]\\+:" | grep -o "[0-9]\\+"`
    local SPIKE_GREY=`echo $RAW_VALUES | sort -n | tail -n 1 | grep -o " ([0-9 ,]*)" | sed 's/ //g'`

    local GEOMETRY=`echo $INFO | grep "Geometry: [0-9]\\+x[0-9]\\+" | grep -o "[0-9]\\+x[0-9]\\+"`
    local X=`echo $GEOMETRY | grep -o "[0-9]\\+x" | grep -o "[0-9]\\+"`
    local Y=`echo $GEOMETRY | grep -o "x[0-9]\\+" | grep -o "[0-9]\\+"`
    local PIXELS=`echo "$X*$Y" | bc`
    
    # http://stackoverflow.com/questions/8402181/how-do-i-get-bc1-to-print-the-leading-zero
    local PERCENT_FIRST=`echo "scale=2;x=$FIRST_COUNT*100/$PIXELS; if(x<1) print 0; x" | bc`
    local PERCENT_LAST=`echo "scale=2;x=$LAST_COUNT*100/$PIXELS; if(x<1) print 0; x" | bc`
    local SPIKE_PERCENT=`echo "scale=2;x=$SPIKE_COUNT*100/$PIXELS; if(x<1) print 0; x" | bc`
    
    echo "$PIXELS $UNIQUE $FIRST_COUNT $PERCENT_FIRST $FIRST_GREY $LAST_COUNT $PERCENT_LAST $LAST_GREY" > "$GREY"

    IFS=$SAVEIFS

    echo "$PIXELS $UNIQUE $FIRST_COUNT $PERCENT_FIRST $FIRST_GREY $LAST_COUNT $PERCENT_LAST $LAST_GREY $SPIKE_COUNT $SPIKE_PERCENT $SPIKE_GREY $ZEROES $HOLES"
}

# Produces a histogram over greyscale intensities in the given image
# Input: image height log
# Sample: foo.jpg 200 true
# Output: foo.png (256 x height pixels) with the histogram
function histogram() {
    local SRC="$1"
    local HEIGHT=$2
    local LOG=$3

    local IDENTIFY=`im_identify "$SRC"`
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

        if [ 0 -lt $PIXELS ]; then
            for P in `seq 0 $PIXELS`; do
                echo -n -e \\x0 >> $HTMP
            done
        fi
        if [ $((HEIGHT-1)) -gt $PIXELS ]; then
            for P in `seq $((PIXELS+1)) $((HEIGHT-1)) `; do
                echo -n -e \\xff >> $HTMP
            done
        fi

#        for P in `seq 0 $((HEIGHT-1))`; do
#            if [ $P -le $PIXELS ]; then
#                echo -n -e \\x0 >> $HTMP
#            else 
#                echo -n -e \\xff >> $HTMP
#            fi
#        done
#        echo "$G $COUNT $PIXELS"
    done
    echo "convert -rotate 270 $HTMP $DEST"
    convert -rotate 270 $HTMP "$DEST"
    ls -l $HTMP
    rm $HTMP
}

# histogram $1 200 false
# grey_stats $1
