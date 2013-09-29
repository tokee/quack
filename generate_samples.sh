#!/bin/bash

#
# Generates sample images with corresponding ALTO files
# The generates ALTOs are not high quality sample ALTOs as they
# does not properly represents TextLines etc. They are only intended
# as input files to quack.
#

# Pseudo-text for TextBlocks
TEXT="Noster laboramus no ius, graece doctus no quo. Eam ea dicta clita, probo option dolorum ius no. Et vis verterem disputationi. An nam assum augue eleifend, per no animal accusam eloquentiam. Veri aliquip scripta no vix, id petentium assentior pri, et usu odio impedit partiendo."
# Page margin
MARGIN=20
MIN_WIDTH=540
MIN_HEIGHT=1000
HEADER_HEIGHT=200
COL_MIN_WIDTH=500
ROW_MAX_HEIGHT=300

COUNTER=1

# Input width height destfile
# Output TEXT
function makeMessage() {
    local WIDTH=$1
    local HEIGHT=$2
    local DEST=$3

    gm convert -size ${WIDTH}x${HEIGHT} canvas:'#666666' ${DEST}
    TEXT="foo bar"
}

# Input: filename imagetype width height
function generate() {
    local BASE=$1
    local TYPE=$2
    local WIDTH=$3
    local HEIGHT=$4

    if [ $WIDTH -lt $MIN_WIDTH ]; then
        echo "Width must be at least $MIN_WIDTH but was $WIDTH"
        exit 2
    fi

    if [ $HEIGHT -lt $MIN_HEIGHT ]; then
        echo "Height must be at least $MIN_HEIGHT but was $HEIGHT"
        exit 2
    fi

    local COLUMNS=`echo "($WIDTH - $MARGIN) / ($COL_MIN_WIDTH + $MARGIN)" | bc`
    local COLUMN_WIDTH=`echo "($WIDTH - 2 * $MARGIN) / $COLUMNS" | bc`
    local ROWS=`echo "($HEIGHT - 2 * $MARGIN - $HEADER_HEIGHT) / ($ROW_MAX_HEIGHT + $MARGIN)" | bc`
    local ROW_HEIGHT=`echo "($HEIGHT - 3 * $MARGIN - $HEADER_HEIGHT) / $ROWS" | bc`

    echo "Generating #${COUNTER} $TYPE and ALTO XML for '$BASE' of ${WIDTH}x${HEIGHT} pixels with ${COLUMNS}x${ROWS} columns of ${COLUMN_WIDTH}x${ROW_HEIGHT} pixels"

    local CANVAS="canvas.tmp.tif"

    convert -size ${WIDTH}x${HEIGHT} canvas:'#f0f0f0' $CANVAS

#    C="-size ${WIDTH}x${HEIGHT} canvas:'#f0f0f0'"
    # TODO: Add light grey gaussian noise and darker speckles to simulate scanned paper
#    C="$C +noise Gaussian"
#    C="$C \"${BASE}.png\""
#    echo "convert $C"
#    eval "convert $C"

    X=$MARGIN
    Y=$MARGIN
    # Generate header
    HEADER="$BASE $COUNTER"
    local HEADER_Y=`echo "$HEIGHT / 2 - $MARGIN - $HEADER_HEIGHT" | bc`
    C="$C -gravity center -font Helvetica -pointsize 150 -fill black -draw \"text 0,-$HEADER_Y '$HEADER'\""
    Y=`echo "$Y + $HEADER_HEIGHT + $MARGIN" | bc`
    for COLUMN in `seq 1 $COLUMNS`; do
        CY=$Y
        for ROW in `seq $ROWS`; do
            local TMP_TXT="/tmp/textimg.tmp.tif"
            makeMessage $COLUMN_WIDTH $ROW_HEIGHT $TMP_IMG
            echo "Block at $X,$CY"
            CY=`echo "$CY + $HEADER_HEIGHT + $MARGIN" | bc`
        done
        X=`echo "$X + $COLUMN_WIDTH + $MARGIN" | bc`
    done

    
    COUNTER=`echo "$COUNTER + 1" | bc`
}

if [ "." == ".$1" -o "." == ".$2" -o "." == ".$3" ]; then
    echo "Usage: ./generate_samples folder width height"
    exit 2
fi

generate $1 png $2 $3
