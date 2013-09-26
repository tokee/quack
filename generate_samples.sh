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

COUNTER=1

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

    local COLUMNS=`echo "($WIDTH - 2 * $MARGIN) / $COL_MIN_WIDTH" | bc`
    local COLUMN_WIDTH=`echo "($WIDTH - 2 * $MARGIN) / $COLUMNS" | bc`
    local COLUMN_HEIGHT=`echo "$HEIGHT - 2 * $MARGIN - $HEADER_HEIGHT" | bc`

    echo "Generating #${COUNTER} $TYPE and ALTO XML for '$BASE' of ${WIDTH}x${HEIGHT} pixels with $COLUMNS columns of ${COLUMN_WIDTH}x${COLUMN_HEIGHT} pixels"
    
    C="-size ${WIDTH}x${HEIGHT} canvas:'#f0f0f0'"
    # TODO: Add light grey gaussian noise and darker speckles to simulate scanned paper
#    C="$C +noise Gaussian"

    # Generate header
    HEADER="$BASE $COUNTER"
    local HEADER_Y=`echo "$HEIGHT / 2 - $MARGIN - $HEADER_HEIGHT" | bc`
    C="$C -gravity center -font Helvetica -pointsize 150 -fill black -draw \"text 0,-$HEADER_Y '$HEADER'\""

    # Add columns
    
    
    C="$C \"${BASE}.png\""
    echo "convert $C"
    eval "convert $C"
    
    COUNTER=`echo "$COUNTER + 1" | bc`
}

if [ "." == ".$1" -o "." == ".$2" -o "." == ".$3" ]; then
    echo "Usage: ./generate_samples folder width height"
    exit 2
fi

generate $1 png $2 $3
