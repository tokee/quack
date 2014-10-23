#!/bin/bash

# 
# Simple statistical analysis of greyscale images.
# Extracts key stats for darkest and brightest intensity, intended
# for use with greyscale_report.sh
#
# Requirements
# * ImageMagick
#

# Input: A greyscale image
# Output: Name pixel_count unique_greyscales #darkest_pixels darkest_pixels_percent darkest_greyscale #brightest_pixels brightest_pixels_percent lightest_greyscale

TMP="`mktemp --suffix .bmp`"

if [ "." == ".$1" ]; then
    echo "Usage: filename [croppercent]"
    exit 2
fi

if [ "." != ".$2" ]; then
    CROP=$2
    convert "$1" -gravity Center -crop $CROP%x+0+0 "$TMP" 2> /dev/null
    INFO=`identify -verbose "$TMP" 2> /dev/null`
    rm "$TMP"
else
    INFO=`identify -verbose $1 2> /dev/null`
fi

#INFO=`cat t`

SAVEIFS=$IFS
IFS=$(echo -en "\n")

UNIQUE=`echo $INFO | grep "[0-9]\\+: (" | wc -l`

FIRST_COUNT=`echo $INFO | grep "[0-9]\\+: (" | head -n 1 | grep -o " [0-9]\\+:" | grep -o "[0-9]\\+"`
FIRST_GREY=`echo $INFO | grep "[0-9]\\+: (" | head -n 1 | grep -o " ([0-9 ,]*)" | sed 's/ //g'`

LAST_COUNT=`echo $INFO | grep "[0-9]\\+: (" | tail -n 1 | grep -o " [0-9]\\+:" | grep -o "[0-9]\\+"`
LAST_GREY=`echo $INFO | grep "[0-9]\\+: (" | tail -n 1 | grep -o " ([0-9 ,]*)" | sed 's/ //g'`

GEOMETRY=`echo $INFO | grep "Geometry: [0-9]\\+x[0-9]\\+" | grep -o "[0-9]\\+x[0-9]\\+"`
X=`echo $GEOMETRY | grep -o "[0-9]\\+x" | grep -o "[0-9]\\+"`
Y=`echo $GEOMETRY | grep -o "x[0-9]\\+" | grep -o "[0-9]\\+"`
PIXELS=`echo "$X*$Y" | bc`

PERCENT_FIRST=`echo "scale=2;$FIRST_COUNT*100/$PIXELS" | bc`
PERCENT_LAST=`echo "scale=2;$LAST_COUNT*100/$PIXELS" | bc`

echo "$1 $PIXELS $UNIQUE $FIRST_COUNT $PERCENT_FIRST $FIRST_GREY $LAST_COUNT $PERCENT_LAST $LAST_GREY"
#echo "$1 $UNIQUE $LAST"

IFS=$SAVEIFS
