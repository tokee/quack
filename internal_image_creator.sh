#!/bin/bash

#
# Creates the sample images for Quack from originals.
# This script is only relevant if the caller has access
# to the original scanned files. These are not stored 
# with the Quack code as their cumulative size is 34MB.
# Contact Toke Eskildsen - te@statsbiblioteket.dk if
# the originals are of interest.
#
# Requires bash & GraphicsMagick
#

ORIGINALS="/mnt/bulk/data/quack_samples"
COMMAND="-geometry 40%x -level 0,1.0,220 -quality 55 -type Grayscale"
FROM_TO="AdresseContoirsEfterretninger-1795-06-16-02-0018B,ACE-17950616-0018B AdresseContoirsEfterretninger-1795-06-16-02-0018B,ACE-17950616-0019A AdresseContoirsEfterretninger-1795-06-16-02-0018B,ACE-17950616-0019B"

# We would like samples from other time periods, but only the 200+ years
# old ones are currently cleared for distribution.
#FROM_TO="AdressecomptoirsEfterretninger-1846-01-20-01-0029A,ACE-18460120-0029A AdressecomptoirsEfterretninger-1846-01-20-01-0031B,ACE-18460120-0031A AdresseContoirsEfterretninger-1795-06-16-02-0018B,ACE-17950616-0018B"
SAMPLES="samples"

if [ ! -d $ORIGINALS ]; then
    echo "The originals folder $ORIGINALS does not exist."
    if [ ! "te" == `whoami` ]; then
        echo "The user name `whoami` indicates you are not Toke Eskildsen."
        echo "This implies that you do not have the originals used to regenerate the samples."
        echo "Please ensure that the originals are available at ${ORIGINALS}."
    fi
    exit 2
fi

if [ ! -d $SAMPLES ]; then
    mkdir $SAMPLES
fi

for FT in $FROM_TO; do
    SRC=`echo "$FT" | cut -d, -f1`
    DEST=`echo "$FT" | cut -d, -f2`
    echo "Generating sample from ${SRC} to ${DEST}"
    gm convert ${ORIGINALS}/${SRC}.png $COMMAND ${SAMPLES}/${DEST}.jpg
    cp ${ORIGINALS}/${SRC}.alto.xml ${SAMPLES}/${DEST}.alto.xml
done
echo "Done"
