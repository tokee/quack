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

# Prints width and height of the given image, separated by space
# Input: Image
function isize() {
    identify -format "%w %h" "$1"
}
export -f isize

# TODO: Accept destination for identify-file as input
# TODO: If FORCE_HISTOGRAM is true, cached identify-files should be deleted
#       to ensure CROP_PERCENT is used

# Input: image [destination]
# Sample: foo.png
# Produces foo.identify if not already existing.
# Output: The name of the identity file
function im_identify() {
    local SRC="$1"
    if [ -n "$2" ]; then
        local DEST_FOLDER="$2"
    else
        local DEST_FOLDER=$(dirname "$SRC")
    fi

    local BASE=${SRC##*/}
    local IDENTIFY=${DEST_FOLDER}/${BASE%%.*}.identify

    if [ -f "$IDENTIFY" ]; then
        echo "$IDENTIFY"
        return
    fi
    if [ "false" == "$ASSUME_GREY" ]; then
        # We do the TIFF-conversion to force greyscale
        local TMP=`mktemp --suffix .tif`
        if [ "." == ".$CROP_PERCENT" ]; then
            gm convert "$SRC" -colorspace gray "$TMP"
        else
            gm convert "$SRC" -gravity Center -crop $CROP_PERCENT%x+0+0 -colorspace gray "$TMP"
        fi
        identify -verbose "$TMP" > "$IDENTIFY"
        rm "$TMP"
    else
        if [ "." == ".$CROP_PERCENT" ]; then
            identify -verbose "$SRC" > "$IDENTIFY"
        else
            local TMP=`mktemp --suffix .tif`
            gm convert "$SRC" -gravity Center -crop $CROP_PERCENT%x+0+0 "$TMP"
            identify -verbose "$TMP" > "$IDENTIFY"
            rm "$TMP"
        fi
    fi
    echo "$IDENTIFY"
}
export -f im_identify

# Outputs all the greyscale values and their counts
# Input: Image [destination]
function greys() {
    local IFILE=`im_identify "$1" "$2"`

    local VALUES=`cat "$IDENTIFY" | grep -A 256 Histogram`
    if [ ! "." == ".`grep Colormap "$IFILE"`" ]; then
        cat "$IFILE" | grep -A 257 Histogram | grep -B 256 Colormap | grep "[0-9]\\+: ("
    else 
        cat "$IFILE" | grep -A 256 Histogram | grep "[0-9]\\+: ("
    fi        
}
export -f greys

# TODO: Accept destination for grey-stats-file as input

# Input: image
# Sample: foo.png
# Produces foo.grey with $PIXELS $UNIQUE $FIRST_COUNT $PERCENT_FIRST $FIRST_GREY $LAST_COUNT $PERCENT_LAST $LAST_GREY
# Output: $PIXELS $UNIQUE $FIRST_COUNT $PERCENT_FIRST $FIRST_GREY $LAST_COUNT $PERCENT_LAST $LAST_GREY $ZEROES $HOLES
function grey_stats() {
    local SRC="$1"
    if [ -n "$2" ]; then
        local DEST_FOLDER="$2"
    else
        local DEST_FOLDER=$(dirname "$SRC")
    fi

    if [ ! -f "$SRC" ]; then
        echo "grey_stats: The file $SRC does not exist in `pwd`" 1>&2
        return
    fi

    local IDENTIFY=$(im_identify "$SRC" "$DEST_FOLDER")

    local BASE=${SRC##*/}
    local GREY=${DEST_FOLDER}/${BASE%%.*}.grey

    local INFO=`cat "$IDENTIFY"`
    local RAW_VALUES=`greys "$SRC" "$DEST_FOLDER"`
    # TODO: No good as the histogram data might be much less than 256
#    local VALUES=`cat "$IDENTIFY" | grep -A 256 Histogram`
#    if [ ! "." == ".`echo "$VALUES" | grep Colormap`" ]; then
#        local VALUES=`echo "$VALUES" | grep -B 256 Colormap`
#    fi        
#    local RAW_VALUES=`echo "$VALUES" | grep "[0-9]\\+: ("`
#    local VALUES="$INFO"
# ***
#    local SAVEIFS=$IFS
    IFS=$(echo -en $"\n")
    
    local UNIQUE=`echo "$RAW_VALUES" | wc -l`

    local FIRST_REAL_GREY=`echo "$RAW_VALUES" | head -n 1 | sed 's/.* ( *\([0-9]\+\),.*/\1/'`

    local UNIQUE_DARKS=0
    if [ ! "1,1,1" == ".$BLOWN_BLACK_BT" ]; then
        # TODO: Add skipping based on BLOWN_BLACK_WT
        local FIRST_COUNT=0
        local MAXG=`echo "$BLOWN_BLACK_BT" | grep -o "^[^,]\+"`
#        echo "$RAW_VALUES" | head -n $MAXG
        IFS=$(echo -en $"\n\b")
        for E in `echo "$RAW_VALUES" | head -n $MAXG`; do
#            echo "e:$E"
            # 81422: (  0,  0,  0) #000000 black
            local C=`echo "$E" | grep -o " [0-9]\\+:" | grep -o "[0-9]\\+"`
            local G=`echo "$E" | grep -o ": \\+([^0-9]*[0-9]\\+," | grep -o "[0-9]\\+"`
#            echo "c:$C g:$G t:$MAXG"
            if [ "$G" -lt "$MAXG" ]; then
                local UNIQUE_DARKS=$((UNIQUE_DARKS+1))
                local FIRST_COUNT=$((FIRST_COUNT+$C))
                local LAST_VALID=$G
            fi
        done
        local FIRST_GREY="0-$LAST_VALID"
        #local FIRST_GREY=`echo "$E" | head -n 1 | grep -o " ([0-9 ,]*)" | sed 's/ //g'`
    else
        local UNIQUE_DARKS=1
        local FIRST_GREY=`echo "$RAW_VALUES" | head -n 1 | sed 's/.* ( *\([0-9]\+\),.*/\1/'`
        local FIRST_COUNT=`echo "$RAW_VALUES" | head -n 1 | grep -o " [0-9]\\+:" | grep -o "[0-9]\\+"`
    fi
    if [ 0 -eq "$FIRST_COUNT" ]; then
        # No pixels from 0-fuzzy_factor
        local UNIQUE_DARKS=1
        local FIRST_GREY=`echo "$RAW_VALUES" | head -n 1 | sed 's/.* ( *\([0-9]\+\),.*/\1/'`
        local FIRST_COUNT=`echo "$RAW_VALUES" | head -n 1 | grep -o " [0-9]\\+:" | grep -o "[0-9]\\+"`
    fi
    IFS=$(echo -en $"\n")

    local LAST_COUNT=`echo "$RAW_VALUES" | tail -n 1 | grep -o " [0-9]\\+:" | grep -o "[0-9]\\+"`
    local LAST_GREY=`echo "$RAW_VALUES" | tail -n 1 | sed 's/.* ( *\([0-9]\+\),.*/\1/'`

    local ZEROES=$((256-UNIQUE))
    local SPAN=$((LAST_GREY-FIRST_REAL_GREY+1))
    local EDGE=$((256-SPAN))
    local HOLES=$((ZEROES-EDGE))
    
    # TODO: Also remove lightest
    local REDUCED=`skipLines "$RAW_VALUES" $UNIQUE_DARKS`
    local REDUCED=`skipLines "$REDUCED" -1`
    local SPIKE_LINE=`echo "$REDUCED" | sort -n | tail -n 1`
    local SPIKE_COUNT=`echo "$SPIKE_LINE" | grep -o " [0-9]\\+:" | grep -o "[0-9]\\+"`
    local SPIKE_GREY=`echo "$SPIKE_LINE" | sed 's/.* ( *\([0-9]\+\),.*/\1/'`

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

#http://stackoverflow.com/questions/5799303/print-a-character-repeatedly-in-bash
# Input: char num
printChar() {
    str=$1
    num=$2
    v=$(printf "%-${num}s" "$str")
    echo "${v// /*}"
}
export -f printChar

# Produces a histogram over greyscale intensities in the given image
# Input: image height log [destination]
# Sample: foo.jpg 200 true foo.hist.png
# Output: foo.png (256 x height pixels) with the histogram
function histogramScript() {
    local SRC="$1"
    local HEIGHT=$2
    local LOG=$3
    local DEST="$4"
    local IDENTIFY_DEST=$(dirname ${DEST})

    local IDENTIFY=`im_identify "$SRC" "$IDENTIFY_DEST"`
    if [ ! -n "$DEST" ]; then
        local DEST=${SRC%%.*}.histogram.png
    fi
    # Convert      
    #   78085: (  0,  0,  0) #000000 black
    #    3410: (  1,  1,  1) #010101 rgb(1,1,1)
    # into
    # 0 78085
    # 1 3410
    GREYS=`greys "$SRC" | sed 's/ \\+\\([0-9]\\+\\): ( *\\([0-9]\\+\\).\\+/\\2 \\1/g'`
    # Find lowest and highest for both intensity and count
    local MIN_GREY=255
    local MAX_GREY=0
    local MIN_COUNT=9999999
    local MAX_COUNT=0
    local TOTAL_COUNT=0

    # Speedup-trick: Read one line of a time instead of splitting up front with for-loop
    while IFS= read -r L
    do
        set -- junk $L
        shift
#        local GREY=`echo "$L" | cut -d\  -f1`
#        local COUNT=`echo "$L" | cut -d\  -f2`
        local GREY=$1
        local COUNT=$2
        local TOTAL_COUNT=$((TOTAL_COUNT+COUNT))
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

#    echo "Grey: $MIN_GREY $MAX_GREY  count: $MIN_COUNT $MAX_COUNT $TOTAL_COUNT"

    if [ -n "$HISTOGRAM_PHEIGHT" ]; then
        if [ ! "auto" == "$HISTOGRAM_PHEIGHT" ]; then
            if [ ! "script_auto" == "$HISTOGRAM_PHEIGHT" ]; then
                local HH=`echo "$HISTOGRAM_PHEIGHT" | grep -o "[0-9]\+"`
                local MAX_COUNT=$((HH*TOTAL_COUNT/100))
            fi
        fi
   fi

    # Let SCALE map all counts from 0 to 100000000 (giga)
    if [ ".true" == ".$LOG" ]; then
        local SCALE=`echo "1000000000/l($MAX_COUNT)" | bc -l`
#        local SCALE=`echo "scale=10;1/l($MAX_COUNT)" | bc -l`
    else
        local SCALE=$((1000000000/MAX_COUNT))
#        local SCALE=`echo "scale=10;1/$MAX_COUNT" | bc -l`
    fi

    # We create a PGM-file with the extracted greyscale statistics
    # as a histogram. The PGM is sideways because it is easier
    # http://netpbm.sourceforge.net/doc/pgm.html
    local HTMP=`mktemp --suffix .pgm`
    if [ "true" == "$LOG" ]; then
        local NONE=1
    else
        local NONE=0
    fi

    echo "P5 $HEIGHT 256 255" > $HTMP

    # Speedup-tricks: Avoid forking as much as possible by doing arithmetic
    # with the built-in $(()). Avoid floating point by scaling up.
    # Output 0 and ff with printf instead of loop.
    for G in `seq 0 255`; do
        local LINE=`echo "$GREYS" | grep "^$G "`
        # http://stackoverflow.com/questions/1469849/how-to-split-one-string-into-multiple-strings-in-bash-shell   
        set -- junk $LINE
        shift
        COUNT=$2
#        local COUNT=`echo "$GREYS" | grep "^$G " | sed 's/[0-9]\\+ \\([0-9]\\+\\)/\\1/g'`
        if [ "." == ".$COUNT" ]; then
            local COUNT=$NONE
        fi
        if [ $COUNT -gt $MAX_COUNT ]; then
            local COUNT=$MAX_COUNT
        fi
        if [ ".true" == ".$LOG" ]; then
            local PIXELS=`echo "scale=10;l($COUNT)/l(10)*$SCALE*$HEIGHT" | bc -l`
            local PIXELS=`echo "scale=0;$PIXELS/1" | bc -l`
#            local PIXELS=`echo "scale=10;l($COUNT)/l(10)*$SCALE*$HEIGHT/1000000000" | bc -l`
        else 
             local PIXELS=$(($COUNT*$SCALE*$HEIGHT/1000000000))
#            local PIXELS=`echo "scale=10;$COUNT*$SCALE*$HEIGHT" | bc -l`
        fi
        # /1 due to funky bc scale not being applied if nothing is done
 #       local PIXELS=`echo "scale=0;$PIXELS/1" | bc -l`

        printf %$((PIXELS))s |tr " " '\0' >> $HTMP
        # 377 octal = ff hex
        printf %$((HEIGHT-PIXELS))s |tr " " '\377' >> $HTMP
#        echo "$G $COUNT $PIXELS"
    done
#    echo "convert $HTMP -rotate 270 $DEST"
    convert $HTMP -rotate 270 "$DEST"
#    ls -l $HTMP
    rm $HTMP
}
export -f histogramScript

#export HISTOGRAM_PHEIGHT="10%"
#time histogramScript $1 200 false
#time histogramScript $1 200 false
#time histogramScript $1 200 false
# grey_stats $1
