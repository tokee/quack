#!/bin/bash

#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# Copyright 2013 Toke Eskildsen, State and University Library, Denmark
#

#
# Quack 1.2 beta - Quality assurance tool for text scanning projects.
# 
# Generates zoomable (OpenSeadragon) views of scanned text pages with overlays
# containing OCR-text from ALTO-files. The views are static HTML pages that
# can be viewed directly from the file system or through a webserver.
#
# Note that the images used for OpenSeadragon are PNG and not tiled, which 
# makes this script a very poor choice for generating pages for end-users.
# The focus is fully on QA, there pixel-perfect reproduction is required.
# The non-tile choice is to minimize storage space.
#
# The script upports iterative updates by re-using existing structures when 
# source files are added and the script is executed again. The destination
# folder is fully self-contained and suitable for mounting under a webserver
# with no access to the original files.
#
# Requirements:
#   Some unix-flavor with bash (only tested under Ubuntu)
#   GraphicsMagick (JPEG2000 -> PNG conversion is twice as fast as ImageMagick)
#   ImageMagick (to create histograms)
#   openseadragon.min.js (download at http://openseadragon.github.io/#download)
#   a fairly current browser with JavaScript enabled
#

# Settings below. Instead of changing this file, it is recommended to
# create a new file "quack.settings" with the wanted setup as it will
# override the defaults below.

# The types of images to pull from source
IMAGE_GLOB="*.tiff *.tif *.jp2 *.jpeg2000 *.j2k *.jpg *.jpeg"
# The extension of the ALTO files corresponding to the image files
# ALTO files are expected to be located next to the image files:
#   OurScanProject_batch_2013-09-18_page_007.tif
#   OurScanProject_batch_2013-09-18_page_007.alto.xml
ALTO_EXT=".alto.xml"

# Sometimes the image corresponding to the ALTO has been scaled after ALTO
# generation. This factor will be multiplied to all ALTO elements. If the
# image has been scaled to half width & half height, set this to 0.5.
ALTO_SCALE_FACTOR="1.0"

# The image format for the QA image. Possible values are png and jpg.
# png is recommended if QA should check image quality in detail.
export IMAGE_DISP_EXT="png"
# If jpg is chosen for IMAGE_DISP_EXT, this quality setting (1-100)
# will be used when genrerating the images.
# Note: This does (unfortunately) not set the quality when tiles and
# jpg has been chosen.
export IMAGE_DISP_QUALITY="95"

# The size of thumbnails in folder view.
export THUMB_IMAGE_SIZE="300x200"

# These elements will be grepped from the ALTO-files and shown on the image pages
ALTO_ELEMENTS="processingDateTime softwareName"

# Number of threads used for image processing. Note that histogram generation
# is very memory hungry (~2GB for a 30MP image). Adjust accordingly.
THREADS=4

# For production it is recommended that all FORCE_ options are set to "false" as
# it makes iterative updates fast. If quack settings are tweaked, the relevant
# FORCE_ options should be "true".

# If true, image-pages will be generated even if they already exists.
export FORCE_PAGES=false
# If true, the main QA-images will be generated even if they already exists.
export FORCE_QAIMAGE=false
# If true, thumbnails will be generated even if they already exists.
export FORCE_THUMBNAILS=false
# If true, blown high- and low-light overlays will be generated even if they already exists.
# Setting this to true will also set FORCE_BLOWN_THUMBS to true
export FORCE_BLOWN=false
# If true, blown high- and low-light overlays for thumbs will be generated even if they already exists.
export FORCE_BLOWN_THUMBS=false
# If true, presentation images will be generated even if they already exists.
export FORCE_PRESENTATION=false
# If true, histogram images will be generated even if they already exists.
export FORCE_HISTOGRAM=false
# If true, tile images will be generated even if they already exists.
# This is only relevant if TILE="true"
export FORCE_TILES=false

# If true, the script attempts to find all alternative versions of the current image
# in other folders under source. Suitable for easy switching between alternate scans
# of the same material.
RESOLVE_ALTERNATIVES=false

# If the IDNEXT attribute starts with 'ART' it is ignored
# Used to avoid visually linking everything on the page
SKIP_NEXT_ART=false

# How much of the image to retain, cropping from center, when calculating
# histograms. Empty value = no crop. Valid values: 1-100
# This us usable for generating proper histograms for scans where the border
# is different from the rest of the image. Artifacts from rotations is an example.
# Suggested values are 85-95%.
CROP_PERCENT=""

# If true, tiles are generated for OpenSeadragon. This requires Robert Barta's 
# deepzoom (see link in README.md) and will generate a lot of 260x260 pixel tiles.
# If false, a single image will be used with OpenSeadragon. This is a lot heavier
# on the browser but avoids the size and file-count overhead of the tiles.
TILE="false"

# If true, a secondary view of the scans will be inserted into the page.
# The view represents an end-user version of the scan. This will often be 
# downscaled, levelled, sharpened and JPEG'ed.
export PRESENTATION="true"

# Overlay colors for indicating burned out high- and low-lights
export OVERLAY_BLACK=3399FF
export OVERLAY_WHITE=FFFF00

# Snippets are inserted verbatim at the top of the folder and the image pages.
# Use them for specifying things like delivery date or provider notes.
export SNIPPET_FOLDER=""
export SNIPPET_IMAGE=""


# End default settings. User-supplied overrides will be loaded from quack.settings


pushd `dirname $0` > /dev/null
ROOT=`pwd`
if [ -e "quack.settings" ]; then
    echo "Sourcing user settings from quack.settings"
    source "quack.settings"
fi
# functions for generating identify-files and extract greyscale statistics
source "analyze.sh"
popd > /dev/null

if [ ".true" == ".$FORCE_BLOWN" ]; then
    # When we force regeneration of blown, we myst also regenerate the blown thumbs.
    export FORCE_BLOWN_THUMBS=true
fi

PRESENTATION_SCRIPT="$ROOT/presentation.sh"
FOLDER_TEMPLATE="$ROOT/folder_template.html"
IMAGE_TEMPLATE="$ROOT/image_template.html"
DRAGON="openseadragon.min.js"

function usage() {
    echo "quack 1.1 beta - Quality Assurance oriented ALTO viewer"
    echo ""
    echo "Usage: ./quack.sh source destination"
    echo ""
    echo "source:      The top folder for images with ALTO files"
    echo "destination: The wanted location of the presentation structure"
    echo ""
    echo "See comments in script and README.md for details."
}

SOURCE=$1
if [ "." == ".$SOURCE" ]; then
    echo "Error: Missing source" >&2
    echo ""
    usage
    exit 2
fi
pushd $SOURCE > /dev/null
SOURCE_FULL=`pwd`
popd > /dev/null

DEST=$2
if [ "." == ".$DEST" ]; then
    echo "Error: Missing destination" >&2
    echo ""
    usage
    exit 2
fi
if [ ! -f "$ROOT/$DRAGON" ]; then
    echo "The file $ROOT/$DRAGON does not exist" >&2
    echo "Please download it at http://openseadragon.github.io/#download" >&2
    exit
fi

# Copy OpenSeadragon and all css-files to destination
function copyFiles () {
    if [ ! -d $DEST ]; then
        echo "Creating folder $DEST"
        mkdir -p $DEST
    fi
    cp "${ROOT}/${DRAGON}" "$DEST"
    cp ${ROOT}/*.js "$DEST"
    cp ${ROOT}/*.css "$DEST"
}

# http://stackoverflow.com/questions/14434549/how-to-expand-shell-variables-in-a-text-file
# Input: template-file
function ctemplate() {
    TMP="`tempfile`.sh"
    echo 'cat <<END_OF_TEXT' >  $TMP
    cat  "$1"                >> $TMP
    echo 'END_OF_TEXT'       >> $TMP
    . $TMP
    rm $TMP
}

# template pattern replacement
# Deprecated in favor of ctemplate due to better speed in ctemplate
function template () {
    local TEMPLATE="$1"
    local PATTERN="$2"
    local REPLACEMENT="$3"
    
    # T="foo\\/:bar\\&amp;"$'\n'"Nextline" ; T=`echo "$T" | sed ':a;N;$!ba;s/\\n/\\\\\&br;/g'` ; echo "zoom" | sed "s/o/$T/g" | sed 's/\&br;/\n/g'

    # We need to escape \, &, / and newline in replacement to avoid sed problems
    # http://stackoverflow.com/questions/407523/escape-a-string-for-sed-search-pattern
    # http://stackoverflow.com/questions/1251999/sed-how-can-i-replace-a-newline-n

    if [ "$REPLACEMENT" == "`echo -n \"$REPLACEMENT\" | tr '\\n' '*'`" ]; then
        # No newlines, especially no trailing ones!
        ( echo -n "s/\${$PATTERN}/" ; echo -n "$REPLACEMENT" | sed -e 's/[\\/&]/\\&/g' | sed ':a;N;$!ba;s/\n/\\\&bt;/g' ; echo "/g" ) | sed -f - -i $TEMPLATE
    else
        # The awk-version always adds a trailing newline, even when the input has none
        ( echo -n "s/\${$PATTERN}/" ; echo -n "$REPLACEMENT" | sed -e 's/[\\/&]/\\&/g' | awk 1 ORS="\\\\&br;" ; echo "/g" ) | sed -f - -i $TEMPLATE
    fi
    # Insert into template, then unescape newlines
    sed 's/\&br;/\n/g' -i $TEMPLATE
}

# Creates the bash environment variables corresponding to those used by makeImages
# This is used to separate HTML generation from the actual image processing
# srcFolder dstFolder image
# Output: SOURCE_IMAGE DEST_IMAGE HIST_IMAGE THUMB
function makeImageParams() {
    local SRC_FOLDER=$1
    local DEST_FOLDER=$2
    local IMAGE=$3

    local SANS_PATH=${IMAGE##*/}
    local BASE=${SANS_PATH%.*}

    # Used by function caller
    # Must be mirrored in makeImages
    SOURCE_IMAGE="${SRC_FOLDER}/${IMAGE}"
    DEST_IMAGE="${DEST_FOLDER}/${BASE}.${IMAGE_DISP_EXT}"
    HIST_IMAGE="${DEST_FOLDER}/${BASE}.histogram.png"
    THUMB_IMAGE="${DEST_FOLDER}/${BASE}.thumb.jpg"
    THUMB_LINK=${THUMB_IMAGE##*/}
    WHITE_IMAGE="${DEST_FOLDER}/${BASE}.white.png"
    BLACK_IMAGE="${DEST_FOLDER}/${BASE}.black.png"
    PRESENTATION_IMAGE="${DEST_FOLDER}/${BASE}.presentation.jpg"
    TILE_FOLDER="${DEST_FOLDER}/${BASE}_files"
}

# If force is true and image exists, image is deleted and true returned
# If force is true and image does not exist, true is returned
# If force is false and image exists, false is returned
# If force is false and image does not exists, true is returned
# Input: force image designation
# Output: true/false. Use with 'if shouldGenerate true dummy; then'
shouldGenerate() {
    local FORCE="$1"
    local IMG="$2"
    local DES="$3"

    if [ ".true" == ".$FORCE" -a -e "$IMG" ]; then
        rm -rf "$IMG"
    fi
    if [ ! -e "$IMG" -a "." != ".$DES" ]; then
        echo " - ${IMG##*/} ($DES)"
    fi
    [ ! -e "$IMG" ]
}
export -f shouldGenerate

# Creates a presentation image and a histogram for the given image
# srcFolder dstFolder image crop presentation_script tile
function makeImages() {
    local SRC_FOLDER=$1
    local DEST_FOLDER=$2
    local IMAGE=$3
    local CROP_PERCENT=$5
    local PRESENTATION_SCRIPT=$6
    local TILE=$7

#    echo "makeImages $SRC_FOLDER $DEST_FOLDER"

    local SANS_PATH=${IMAGE##*/}
    local BASE=${SANS_PATH%.*}

    # Must mirror the ones in makeImageParams
    # Do not cheat by calling makeImageParams as makeImages might
    # be called in parallel
    local SOURCE_IMAGE="${SRC_FOLDER}/${IMAGE}"
    local DEST_IMAGE="${DEST_FOLDER}/${BASE}.${IMAGE_DISP_EXT}"
    local HIST_IMAGE="${DEST_FOLDER}/${BASE}.histogram.png"
    local THUMB_IMAGE="${DEST_FOLDER}/${BASE}.thumb.jpg"
    local THUMB_LINK=${THUMB_IMAGE##*/}
    local WHITE_IMAGE="${DEST_FOLDER}/${BASE}.white.png"
    local BLACK_IMAGE="${DEST_FOLDER}/${BASE}.black.png"
    local THUMB_OVERLAY_WHITE="${DEST_FOLDER}/${BASE}.white.thumb.png"
    local THUMB_OVERLAY_BLACK="${DEST_FOLDER}/${BASE}.black.thumb.png"
    local PRESENTATION_IMAGE="${DEST_FOLDER}/${BASE}.presentation.jpg"
    local TILE_FOLDER="${DEST_FOLDER}/${BASE}_files"

    if [ ! -f $SOURCE_IMAGE ]; then
        echo "The source image $S does not exists" >&2
        exit
    fi

    # Even if TILE="true", we create the full main presentational image as it
    # might be requested for download
    if shouldGenerate "$FORCE_QAIMAGE" "$DEST_IMAGE" "QA"; then
        gm convert "$SOURCE_IMAGE" -quality $IMAGE_DISP_QUALITY "$DEST_IMAGE"
    fi

    if [ "png" == ${IMAGE_DISP_EXT} ]; then
        # PNG is fairly fast to decode so use that as source
        local CONV="$DEST_IMAGE"
    else
        local CONV="$SOURCE_IMAGE"
    fi

    if [ ".true" == ".$TILE" ]; then
        if shouldGenerate "$FORCE_TILES" "$TILE_FOLDER" "tiles"; then
        # TODO: Specify JPEG quality
            deepzoom "$CONV" -format $IMAGE_DISP_EXT -path "${DEST_FOLDER}/"
        fi
    fi

    if shouldGenerate "$FORCE_BLOWN" "$WHITE_IMAGE" "overlay"; then
        gm convert "$CONV" -black-threshold 255,255,255 -white-threshold 254,254,254 -negate -fill \#$OVERLAY_WHITE -opaque black -transparent white -colors 2 "$WHITE_IMAGE"
    fi

    if shouldGenerate "$FORCE_BLOWN" "$BLACK_IMAGE" "overlay"; then
        gm convert "$CONV" -black-threshold 1,1,1 -white-threshold 0,0,0 -fill \#$OVERLAY_BLACK -opaque black -transparent white -colors 2 "$BLACK_IMAGE"
    fi

    if [ ".true" == ".$PRESENTATION" ]; then
        if shouldGenerate "$FORCE_PRESENTATION" "$PRESENTATION_IMAGE" "presentation"; then
            echo "Should generate"
            $PRESENTATION_SCRIPT "$CONV" "$PRESENTATION_IMAGE"
        fi
    fi

    if shouldGenerate "$FORCE_HISTOGRAM" "$HIST_IMAGE" "histogram"; then
        # Remove "-separate -append" to generate a RGB histogram
        # http://www.imagemagick.org/Usage/files/#histogram
        if [ "." == ".$CROP_PERCENT" ]; then
            convert "$CONV" -separate -append -define histogram:unique-colors=false -write histogram:mpr:hgram +delete mpr:hgram -negate -strip "$HIST_IMAGE"
        else
            convert "$CONV" -gravity Center -crop $CROP_PERCENT%x+0+0 -separate -append -define histogram:unique-colors=false -write histogram:mpr:hgram +delete mpr:hgram -negate -strip "$HIST_IMAGE"
        fi
    fi

    if shouldGenerate "$FORCE_THUMBNAILS" "$THUMB_IMAGE" "thumbnail"; then
        gm convert "$CONV" -sharpen 3 -enhance -resize $THUMB_IMAGE_SIZE "$THUMB_IMAGE"
    fi

    if shouldGenerate "$FORCE_BLOWN_THUMBS" "$THUMB_OVERLAY_WHITE" "thumb overlay"; then
        echo " - ${THUMB_OVERLAY_WHITE##*/}"
        # Note: We use ImageMagick here as older versions of GraphicsMagic does not
        # handle resizing of alpha-channel PNGs followed by color reduction
        convert "$WHITE_IMAGE" -resize $THUMB_IMAGE_SIZE -colors 2 "$THUMB_OVERLAY_WHITE"
    fi
    if shouldGenerate "$FORCE_BLOWN_THUMBS" "$THUMB_OVERLAY_BLACK" "thumb overlay"; then
        echo " - ${THUMB_OVERLAY_BLACK##*/}"
        # Note: We use ImageMagick here as older versions of GraphicsMagic does not
        # handle resizing of alpha-channel PNGs followed by color reduction
        convert "$BLACK_IMAGE" -resize $THUMB_IMAGE_SIZE -colors 2 "$THUMB_OVERLAY_BLACK"
    fi
}
export -f makeImages

# Generates overlays for the stated block and updates idnext & idprev
# altoxml (newlines removed) tag class
# Output (addition): IDNEXTS IDPREVS OVERLAYS OCR_CONTENT
function processElements() {
    local ALTOFLAT=$1
    local TAG=$2
    local CLASS=$3

#    echo "processGenericOverlay <altoflat> $TAG $CLASS"
    # Insert newlines before </$TAG>
    ELEMENTS=`echo $ALTOFLAT | sed "s/<$TAG/\\n<$TAG/g" | grep "<$TAG"`
#    local ELEMENTS=`echo $ALTOFLAT | sed "s/<\/$TAG>/<\/$TAG>\\n/g"`
    local SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")
    # http://mywiki.wooledge.org/BashFAQ/001
    while IFS= read -r B
    do
#        echo -n "."
#    for B in $ELEMENTS ; do
        local BTAG=`echo "$B" | grep -o "<$TAG[^>]\+>"`
        local BID=`echo $BTAG | sed 's/.*ID=\"\([^"]\+\)".*/\\1/g'`
        if [ "." == ".$BID" ]; then
            continue
        fi
        local BIDNEXT=`echo $BTAG | sed 's/.*IDNEXT=\"\([^"]\+\)".*/\\1/g'`
        if [ "." != ".$BIDNEXT" -a "$BTAG" != "$BIDNEXT" ]; then
            local PRE_ART=`echo "$BIDNEXT" | grep -o "^ART"`
            if [ ".true" == ".$SKIP_NEXT_ART" ]; then
                if [ ".ART" == ".$PRE_ART" ]; then
                    BIDNEXT=""
                fi
            fi
            IDNEXTS="${IDNEXTS}nexts[\"${BID}\"] = \"$BIDNEXT\";"$'\n'
            IDPREVS="${IDPREVS}prevs[\"${BIDNEXT}\"] = \"$BID\";"$'\n'
        fi
        local BHEIGHT=`echo $BTAG | sed 's/.*HEIGHT=\"\([^"]\+\)".*/\\1/g'`
        local BWIDTH=`echo $BTAG | sed 's/.*WIDTH=\"\([^"]\+\)".*/\\1/g'`
        local BHPOS=`echo $BTAG | sed 's/.*HPOS=\"\([^"]\+\)".*/\\1/g'`
        local BVPOS=`echo $BTAG | sed 's/.*VPOS=\"\([^"]\+\)".*/\\1/g'`
        
        local SWIDTH=`echo "scale=6;$BWIDTH/$PWIDTH*$ALTO_SCALE_FACTOR" | bc | sed 's/^\./0./'`
        # TODO: Seems like there is some mismatch going on here with some deliveries
        local SHEIGHT=`echo "scale=6;$BHEIGHT/$PHEIGHT*$ALTO_SCALE_FACTOR" | bc | sed 's/^\./0./'`
#        SHEIGHT=`echo "scale=6;$BHEIGHT/$PWIDTH" | bc | sed 's/^\./0./'`
        local SHPOS=`echo "scale=6;$BHPOS/$PWIDTH*$ALTO_SCALE_FACTOR" | bc | sed 's/^\./0./'`
        local SVPOS=`echo "scale=6;$BVPOS/$PHEIGHT*$ALTO_SCALE_FACTOR" | bc | sed 's/^\./0./'`

        # Special handling of TextBlock
        if [ "TextBlock" == "$TAG" ]; then
            BCONTENT=`echo "$B" | grep -o 'CONTENT="[^"]\+"' | sed 's/CONTENT="\\([^"]\\+\\)"/\\1/g' | sed ':a;N;$!ba;s/\\n/ /g' | sed 's/\\\\/\\\\\\\\/g'`
            # TODO: Handle entity-escaped content as well as quotes and backslash
            OCR_CONTENT="${OCR_CONTENT}ocrs[\"${BID}\"] = \"$BCONTENT\";"$'\n'
#            echo "ocrs[\"${BID}\"] = \"$BCONTENT\";"$'\n'
        fi

        OVERLAYS="${OVERLAYS}    {id: '$BID',"$'\n'
        OVERLAYS="${OVERLAYS}      x: $SHPOS, y: $SVPOS, width: $SWIDTH, height: $SHEIGHT,"$'\n'
        OVERLAYS="${OVERLAYS}      className: '$CLASS'"$'\n'
        OVERLAYS="${OVERLAYS}    },"$'\n'
    done <<< "$ELEMENTS"
    IFS=$SAVEIFS
}

# Generates JavaScript snippet for black and white overlays
# Input: src
# Output: OVERLAYS (not terminated with ']')
function blackWhite() {
    local SRC="$1"
    local IMAGE_WIDTH=$2
    local IMAGE_HEIGHT=$3
    local REL_HEIGHT=`echo "scale=2;$IMAGE_HEIGHT/$IMAGE_WIDTH" | bc`

    # Special overlays to show absolute black and absolute white pixels
    # The FULL_REL is a hack as OpenSeaDragon scales with respect to width
    OVERLAYS="overlays: ["$'\n'
    OVERLAYS="${OVERLAYS}{id: 'white',"$'\n'
    OVERLAYS="${OVERLAYS}  x: 0.0, y: 0.0, width: 1.0, height: $REL_HEIGHT,"$'\n'
    OVERLAYS="${OVERLAYS}  className: 'whiteoverlay'"$'\n'
    OVERLAYS="${OVERLAYS}},"$'\n'
    OVERLAYS="${OVERLAYS}{id: 'black',"$'\n'
    OVERLAYS="${OVERLAYS}  x: 0.0, y: 0.0, width: 1.0, height: $REL_HEIGHT,"$'\n'
    OVERLAYS="${OVERLAYS}  className: 'blackoverlay'"$'\n'
    OVERLAYS="${OVERLAYS}},"$'\n'
}

# Generates overlayscase 
# src dest altofile width height
# Output: ELEMENTS_HTML OVERLAYS OCR_CONTENT IDNEXT_CONTENT FULL_RELATIVE_HEIGHT ACCURACY
function processALTO() {
    local SRC="$1"
    local DEST="$2"
    local ALTO_FILE="$3"
    local IMAGE_WIDTH=$4
    local IMAGE_HEIGHT=$5
#    local WIDTH=$4
#    local HEIGHT=$5

    # Used by caller
    OVERLAYS=""
    ELEMENTS_HTML=""
    OCR_CONTENT=""

    local ALTO="${SRC_FOLDER}/${ALTO_FILE}"
    blackWhite "$SRC" $IMAGE_WIDTH $IMAGE_HEIGHT
    # TODO: Extract relevant elements from the Alto for display
    if [ ! -f $ALTO ]; then
        # TODO: Better handling of non-existence
            ELEMENTS_HTML="<p class=\"warning\">No ALTO file at $ALTO</p>"$'\n'
            # Terminate the black/white overlay and return
            OVERLAYS="${OVERLAYS}]"
        return
    fi
    cp "$ALTO" "$DEST"
    # Extract key elements from the ALTO
    local ALTO_COMPACT=`cat "$ALTO_FILE" | sed ':a;N;$!ba;s/\\n/ /g'`
#    local PTAG=`echo "$ALTO_COMPACT" | grep -o "<PrintSpace[^>]\\+>"`
    local PTAG=`echo "$ALTO_COMPACT" | grep -o "<Page[^>]\\+>"`
    local PHEIGHT=`echo $PTAG | sed 's/.*HEIGHT=\"\([^"]\+\)".*/\\1/g'`
    local PWIDTH=`echo $PTAG | sed 's/.*WIDTH=\"\([^"]\+\)".*/\\1/g'`
    ACCURACY=`echo $PTAG | sed 's/.*ACCURACY=\"\([^"]\+\)".*/\\1/g'`

    FULL_RELATIVE_HEIGHT=`echo "scale=6;$PHEIGHT/$PWIDTH" | bc | sed 's/^\./0./'`
    # TODO: Ponder how relative positioning works and why this hack is necessary
    # Theory #1: OpenSeadragon messes up the vertical relative positioning
    PHEIGHT=$PWIDTH

    ELEMENTS_HTML="<table class=\"altoelements\"><tr><th>Key</th> <th>Value</th></tr>"$'\n'
    for E in $ALTO_ELEMENTS; do
        SAVEIFS=$IFS
        IFS=$(echo -en "\n\b")
        for V in `echo "$ALTO_COMPACT" | grep -o "<${E}>[^<]\\+</${E}>"`; do
            TV=`echo "$V" | sed 's/.*>\(.*\)<.*/\\1/g'`
            ELEMENTS_HTML="${ELEMENTS_HTML}<tr><td>$E</td> <td>$TV</td></tr>"$'\n'
        done
        IFS=$SAVEIFS
    done
    ELEMENTS_HTML="${ELEMENTS_HTML}</table>"$'\n'

    OCR_CONTENT=""
    IDNEXTS=""
    IDPREVS=""

    # Remove newlines from the ALTO
    SANS=`cat $ALTO | sed ':a;N;$!ba;s/\\n/ /g'`

    processElements "$SANS" "ComposedBlock" "composed"
    processElements "$SANS" "Illustration" "illustration"
    processElements "$SANS" "TextBlock" "highlight"

    OVERLAYS="${OVERLAYS}   ]"$'\n'
}

# Searches from the root for alternative versions of the given image
# Very specific to Statsbiblioteket
# src_folder image
# Output: ALTERNATIVES_HTML
function resolveAlternatives() {
    local SRC_FOLDER=$1
    local IMAGE=$2
    local FULL="${SRC_FOLDER}/${IMAGE}"
#    local ID=`echo $IMAGE | grep -o "[0-9][0-9][0-9][0-9]-.*"`
    local ID="${IMAGE%.*}"

    if [ "." == ".$ID" ]; then
        echo "   Unable to extract ID for \"$IMAGE\". No alternatives lookup"
        return
    fi

    pushd $SOURCE_FULL > /dev/null
    ALTERNATIVES_HTML="<ul class=\"alternatives\">"$'\n'
    for A in `find . -name "*${ID}" | sort`; do
        # "../../.././Apex/B3/2012-01-05-01/Dagbladet-2012-01-05-01-0130B.jp2 -> Apex/B3
       local LINK=`echo $A | sed 's/[./]\\+\\([^\\/]\\+\\/[^\\/]\\+\\).*/\\1/g'`
       local D="${A%.*}"
       ALTERNATIVES_HTML="${ALTERNATIVES_HTML}<li><a href=\"${UP}${D}.html\">${LINK}</a></li>"$'\n'
    done
    ALTERNATIVES_HTML="${ALTERNATIVES_HTML}</ul>"$'\n'
    popd > /dev/null
}

# Creates only the HTML page itself. The corresponding makeImages must
# be called before calling this function
# up parent srcFolder dstFolder image prev_image next_image
# Output: PAGE_LINK BASE THUMB_LINK THUMB_WIDTH THUMB_HEIGHT
function makePreviewPage() {
    local UP="$1"
    local PARENT="$2"
    local SRC_FOLDER="$3"
    local DEST_FOLDER="$4"
    local IMAGE="$5"
    local PREV_IMAGE="$6"
    local NEXT_IMAGE="$7"

    local SANS_PATH=${IMAGE##*/}
    BASE=${SANS_PATH%.*}
    P="${DEST_FOLDER}/${BASE}.html"

    # Used by function caller
    PAGE_LINK="${BASE}.html"

    makeImageParams "$SRC_FOLDER" "$DEST_FOLDER" "$IMAGE"

    if [ ! -e "$DEST_IMAGE" ]; then
        echo "The destination image '$DEST_IMAGE' for '$IMAGE' has not been created" >&2
        exit
    fi

    local IDENTIFY=`identify "$DEST_IMAGE" | grep -o " [0-9]\+x[0-9]\\+ "`
    IMAGE_WIDTH=`echo $IDENTIFY | grep -o "[0-9]\+x" | grep -o "[0-9]\+"`
    IMAGE_HEIGHT=`echo $IDENTIFY | grep -o "x[0-9]\+" | grep -o "[0-9]\+"`
    local TIDENTIFY=`identify "$THUMB_IMAGE" | grep -o " [0-9]\+x[0-9]\\+ "`
    THUMB_WIDTH=`echo $TIDENTIFY | grep -o "[0-9]\+x" | grep -o "[0-9]\+"`
    THUMB_HEIGHT=`echo $TIDENTIFY | grep -o "x[0-9]\+" | grep -o "[0-9]\+"`

    if [ ".true" == ".$PRESENTATION" ]; then
        local PIDENTIFY=`identify "$PRESENTATION_IMAGE" | grep -o " [0-9]\+x[0-9]\\+ "`
        PRESENTATION_WIDTH=`echo $PIDENTIFY | grep -o "[0-9]\+x" | grep -o "[0-9]\+"`
        PRESENTATION_HEIGHT=`echo $PIDENTIFY | grep -o "x[0-9]\+" | grep -o "[0-9]\+"`
    fi
   
    if [ "true" != "$FORCE_PAGES" -a -e "$P" ]; then
        return
    fi

    echo " - ${P##*/}"

    local ALTO_FILE="${BASE}${ALTO_EXT}"
    processALTO "$SRC_FOLDER" "$DEST_FOLDER" "$ALTO_FILE" $IMAGE_WIDTH $IMAGE_HEIGHT
# $IMAGE_WIDTH $IMAGE_HEIGHT

    local NAVIGATION=""
    if [ ! "." == ".$PREV_IMAGE" ]; then
        local PSANS_PATH=${PREV_IMAGE##*/}
        local PBASE=${PSANS_PATH%.*}
        NAVIGATION="<a href=\"${PBASE}.html\">previous</a> | "
    else 
        # We write the text to keep the positions of the links constant
        NAVIGATION="previous | "
    fi
    NAVIGATION="${NAVIGATION}<a href=\"index.html\">up</a>"
    if [ ! "." == ".$NEXT_IMAGE" ]; then
        local NSANS_PATH=${NEXT_IMAGE##*/}
        local NBASE=${NSANS_PATH%.*}
        NAVIGATION="${NAVIGATION} | <a href=\"${NBASE}.html\">next</a>"
    else
        NAVIGATION="${NAVIGATION} | next"
    fi



    # PARENT, DATE, UP, NAVIGATION, BASE, SOURCE, FULL_RELATIVE_HEIGHT, EDEST, IMAGE_WIDTH, IMAGE_HEIGHT, TILE_SOURCES, THUMB, THUMB_WIDTH, THUMB_HEIGHT, PRESENTATION, PRESENTATION_WIDTH, PRESENTATION_HEIGHT, WHITE, BLACK, OVERLAYS, OCR_CONTENT, IDNEXTS, IDPREVS, ALTO_ELEMENTS_HTML, HISTOGRAM, ALTO, ALTERNATIVES
    SOURCE="$SOURCE_IMAGE"
    EDEST=${DEST_IMAGE##*/}
    IMAGE="$EDEST"

    if [ "true" == "$TILE" ]; then
        TILE_SOURCES="      Image: {\
        xmlns:    \"http://schemas.microsoft.com/deepzoom/2008\",\
        Url:      \"${TILE_FOLDER##*/}/\",\
        Format:   \"$IMAGE_DISP_EXT\",\
        Overlap:  \"4\",\
        TileSize: \"256\",\
        Size: {\
          Width:  \"$IMAGE_WIDTH\",\
          Height: \"$IMAGE_HEIGHT\"\
        }\
      }"$'\n'
    else
        TILE_SOURCES="      type: 'legacy-image-pyramid',\
      levels:[\
        {\
          url: '${EDEST}',\
          width:  ${IMAGE_WIDTH},\
          height: ${IMAGE_HEIGHT}\
        }\
      ]"$'\n'
    fi
    THUMB="$THUMB_LINK"
    if [ ".true" == ".$PRESENTATION" ]; then
        PRESENTATION_LINK=${PRESENTATION_IMAGE##*/}
    else
        PRESENTATION_LINK=""
        PRESENTATION_WIDTH=0
        PRESENTATION_HEIGHT=0
    fi
    WHITE_LINK=${WHITE_IMAGE##*/}
    WHITE="$WHITE_LINK"
    BLACK_LINK=${BLACK_IMAGE##*/}
    BLACK="$BLACK_LINK"

    ALTO_ELEMENTS_HTML="$ELEMENTS_HTML"
    EHIST=${HIST_IMAGE##*/}
    HISTOGRAM="$EHIST"
    ALTO="$ALTO_FILE"
    if [ "true" == "$RESOLVE_ALTERNATIVES" ]; then
        resolveAlternatives "$SRC_FOLDER" "$IMAGE"
    else
        local ALTERNATIVES_HTML=""
    fi
    ALTERNATIVES="$ALTERNATIVES_HTML"

    # image stats
#    grey_stats "$IMAGE"
    # TODO: Use destination if that is lossless and faster to open?
    local GREY=`grey_stats "$SOURCE_IMAGE"`

    # $PIXELS $UNIQUE $FIRST_COUNT $PERCENT_FIRST $FIRST_GREY $LAST_COUNT $PERCENT_LAST $LAST_GREY
    # 1000095 512 82362 8.23 (0,0,0) 255 .02 (255,255,255)
    GREY_PIXELS=`echo "$GREY" | cut -d\  -f1`
    GREY_UNIQUE=`echo "$GREY" | cut -d\  -f2`
    GREY_COUNT_FIRST=`echo "$GREY" | cut -d\  -f3`
    GREY_PERCENT_FIRST=`echo "$GREY" | cut -d\  -f4`
    GREY_FIRST=`echo "$GREY" | cut -d\  -f5`
    GREY_COUNT_LAST=`echo "$GREY" | cut -d\  -f6`
    GREY_PERCENT_LAST=`echo "$GREY" | cut -d\  -f7`
    GREY_LAST=`echo "$GREY" | cut -d\  -f8`
    local GREY_ALL_SOURCE=`im_identify $SOURCE_IMAGE`
    GREY_ALL=`cat "$GREY_ALL_SOURCE" | grep -A 256 Histogram | tail -n 256`

    ctemplate $IMAGE_TEMPLATE > $P
   
#    ls -l "$IMAGE"
#   echo "$GREY"
    # ***
 #    echo ""

#    cat $P
#    exit

 }

# Input: up parent srcFolder dstFolder
#
function makeIndex() {
    local UP=$1
    local PARENT=$2
    local SRC_FOLDER=$3
    local DEST_FOLDER=$4
#    echo "Processing level '$PARENT' from $SRC_FOLDER"

    if [ ! -d $SRC_FOLDER ]; then
        echo "Unable to locate folder $SRC_FOLDER from `pwd`" >&2
        exit
    fi
    pushd $SRC_FOLDER > /dev/null
    local SRC_FOLDER=`pwd`
    popd > /dev/null
    echo "Processing $SRC_FOLDER"

    if [ ! -d $DEST_FOLDER ]; then
#        echo "Creating folder $DEST_FOLDER"
        mkdir -p $DEST_FOLDER
    fi
    pushd $DEST_FOLDER > /dev/null
    local DEST_FOLDER=`pwd`
    popd > /dev/null

    pushd $SRC_FOLDER > /dev/null
    local PP="${DEST_FOLDER}/index.html"

    if [ "." == ".$PARENT" ]; then
        true
#        echo "<p>Parent: N/A</p>" >> $PP
    fi

    # Images
    local IMAGES=`ls $IMAGE_GLOB 2> /dev/null`

    # Generate graphics
    # http://stackoverflow.com/questions/11003418/calling-functions-with-xargs-within-a-bash-script
    echo "$IMAGES" | xargs -n 1 -I'{}' -P $THREADS bash -c 'makeImages "$@"' _ "$SRC_FOLDER" "$DEST_FOLDER" "{}" "$THUMB_IMAGE_SIZE" "$CROP_PERCENT" "$PRESENTATION_SCRIPT" "$TILE" \;

    # Generate pages
    local THUMBS_HTML=""
    local PREV_IMAGE=""
    if [ "." == ".$IMAGES" ]; then
        IMAGES_HTML="<p>No images</p>"$'\n'
    else
        IMAGES_HTML="<ul>"$'\n'
        for I in $IMAGES; do
            local NEXT_IMAGE=`echo "$IMAGES" | grep -A 1 "$I" | tail -n 1 | grep -v "$I"`
            makePreviewPage "$UP" "$PARENT" "$SRC_FOLDER" "$DEST_FOLDER" "$I" "$PREV_IMAGE" "$NEXT_IMAGE"
            IMAGES_HTML="${IMAGES_HTML}<li><a href=\"$PAGE_LINK\">$BASE</a></li>"$'\n'

            THUMBS_HTML="${THUMBS_HTML}<div class=\"thumb\"><a class=\"thumblink\" href=\"$PAGE_LINK\"><span class=\"thumboverlay\"></span><img class=\"thumbimg\" src=\"${THUMB_LINK}\" alt=\"$BASE\" title=\"$BASE\" width=\"$THUMB_WIDTH\" height=\"$THUMB_HEIGHT\"/></a></div>"$'\n'
#            THUMBS_HTML="${THUMBS_HTML}<a class=\"thumblink\" href=\"$PAGE_LINK\"><img class=\"thumbimg\" src=\"${THUMB_LINK}\" alt=\"$BASE\" title=\"$BASE\" width=\"$THUMB_WIDTH\" height=\"$THUMB_HEIGHT\"/></a>"$'\n'
            PREV_IMAGE=$I
        done
        IMAGES_HTML="${IMAGES_HTML}</ul>"$'\n'
    fi

    local SUBS=`ls $SRC_FOLDER`
    if [ "." == ".$S
    UBS" ]; then
        SUBFOLDERS_HTML="<p>No subfolders</p>"$'\n'
    else
        SUBFOLDERS_HTML="<ul>"$'\n'
        for F in $SUBS; do
            if [ -d $F ]; then
                SUBFOLDERS_HTML="${SUBFOLDERS_HTML}<li><a href=\"$F/index.html\">$F</a></li>"$'\n'
            fi
        done
        SUBFOLDERS_HTML="${SUBFOLDERS_HTML}</ul>"$'\n'
    fi

    if [ ! -f *.Edition.xml ]; then
        # TODO: Only warn if there are images
        EDITION_HTML=`echo "<p class=\"warning\">No edition</p>"`
    else
        EDITION_HTML=""
        for E in *.Edition.xml; do
            # echo to get newlines
            EDITION_HTML="${EDITION_HTML}<p>$E</p>"$'\n'
            EDITION_HTML="${EDITION_HTML}<pre>"$'\n'
            cat $E | sed -e 's/&/&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'  -e 's/\&gt;\([^\&]\+\)\&lt;/\&gt;<span class="xmlvalue">\1<\/span>\&lt;/g' > /tmp/t_edition
#            cat $E | sed -e 's/&/&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'  -e 's/\&lt;([^\&]+)\&gt;/\&lt;<span class="xmlvalue">\1</span>\&gt;/g' > /tmp/t_edition
            EDITION_HTML="${EDITION_HTML}`cat /tmp/t_edition`"$'\n'
            rm /tmp/t_edition
            EDITION_HTML="${EDITION_HTML}</pre>"$'\n'
        done
    fi

    # UP, PARENT, SRC_FOLDER, DEST_FOLDER, IMAGES_HTML, THUMBS_HTML, SUBFOLDERS_HTML, EDITION_HTML
    ctemplate $FOLDER_TEMPLATE > $PP
    
    # Generate pages for sub folders
    # We do this at the end to avoid overriding of variables
    for F in $SUBS; do
        if [ -d $F ]; then
            makeIndex "${UP}../" "${PARENT}${F}/" "${SRC_FOLDER}/${F}" "${DEST_FOLDER}/${F}"
        fi
    done

    popd > /dev/null
 }

echo "Quack starting at `date`"
copyFiles
makeIndex "" "" $SOURCE $DEST
echo "All done at `date`"
echo "Please open ${DEST}/index.html in a browser"
