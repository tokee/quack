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

    local COLUMNS=`echo "\($WIDTH - 2 * $MARGIN\) % 

    echo "Generating $TYPE and ALTO XML for '$BASE' of ${WIDTH}x${HEIGHT} pixels"


    
}

generate $1 png $2 $3
