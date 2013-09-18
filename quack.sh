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
# Quack 1.0 beta - Quality assurance tool for text scanning projects.
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
export IMAGE_DISP_EXT="png"
export THUMB_IMAGE_SIZE="300x200"
# These elements will be grepped from the ALTO-files and shown on the image pages
ALTO_ELEMENTS="processingDateTime softwareName"
# If true, preview-pages will not be regenerated
SKIP_EXISTING_PREVIEWS=true
THREADS=4
# If true, thumbnails are generated even if they already exists
FORCE_THUMBNAILS=false
# If true, the script attempts to find all alternative versions of the current image
# based on the file name. Highly Statsbiblioteket-specific!
RESOLVE_ALTERNATIVES=false
# If the IDNEXT attribute starts with 'ART' it is ignored
# Used to avoid visually linking everything on the page
# False as Ninestars uses ART for each TextBlock
SKIP_NEXT_ART=false
# How much of the image to retain, cropping from center, when calculating
# histogram. Empty value = no crop. Valid values: 1-100
CROP_PERCENT=""

pushd `dirname $0` > /dev/null
ROOT=`pwd`
if [ -e "quack.settings" ]; then
    echo "Sourcing settings from quack.settings"
    source "quack.settings"
fi
PRESENTATION_SCRIPT="$ROOT/presentation.sh"
popd > /dev/null

FOLDER_TEMPLATE="$ROOT/folder_template.html"
IMAGE_TEMPLATE="$ROOT/image_template.html"
DRAGON="openseadragon.min.js"

function usage() {
    echo "./quack.sh source destination"
    echo ""
    echo "source:      The top folder for images with ALTO files"
    echo "destination: The wanted location of the presentation structure"
}

SOURCE=$1
if [ "." == ".$SOURCE" ]; then
    echo "Error: Missing source" >&2
    echo ""
    usage
    exit
fi
pushd $SOURCE > /dev/null
SOURCE_FULL=`pwd`
popd > /dev/null

DEST=$2
if [ "." == ".$DEST" ]; then
    echo "Error: Missing destination" >&2
    echo ""
    usage
    exit
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
    cp "${ROOT}/quack.js" "$DEST"
    cp ${ROOT}/*.css "$DEST"
}

# template pattern replacement
function template () {
    local TEMPLATE="$1"
    local PATTERN="$2"
    local REPLACEMENT="$3"
    
    # T="foo\\/:bar\\&amp;"$'\n'"Nextline" ; T=`echo "$T" | sed ':a;N;$!ba;s/\\n/\\\\\&br;/g'` ; echo "zoom" | sed "s/o/$T/g" | sed 's/\&br;/\n/g'

    # We need to escape \, &, / and newline in replacement to avoid sed problems
    # http://stackoverflow.com/questions/407523/escape-a-string-for-sed-search-pattern
    # http://stackoverflow.com/questions/1251999/sed-how-can-i-replace-a-newline-n
    local EREPLACEMENT=`echo "$REPLACEMENT" | sed -e 's/[\\/&]/\\\\&/g' | sed ':a;N;$!ba;s/\\n/\\\\\&br;/g'`
    # Insert into template, then unescape newlines
    echo "$TEMPLATE" | sed "s/\${$PATTERN}/$EREPLACEMENT/g" | sed 's/\&br;/\n/g'
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
    WHITE_IMAGE="${DEST_FOLDER}/${BASE}.white.png"
    BLACK_IMAGE="${DEST_FOLDER}/${BASE}.black.png"
    PRESENTATION_IMAGE="${DEST_FOLDER}/${BASE}.presentation.jpg"
}

# Creates a presentation image and a histogram for the given image
# srcFolder dstFolder image crop presentation_script
function makeImages() {
    local SRC_FOLDER=$1
    local DEST_FOLDER=$2
    local IMAGE=$3
    local CROP_PERCENT=$5
    local PRESENTATION_SCRIPT=$6

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
    local WHITE_IMAGE="${DEST_FOLDER}/${BASE}.white.png"
    local BLACK_IMAGE="${DEST_FOLDER}/${BASE}.black.png"
    local PRESENTATION_IMAGE="${DEST_FOLDER}/${BASE}.presentation.jpg"

    if [ ! -f $SOURCE_IMAGE ]; then
        echo "The source image $S does not exists" >&2
        exit
    fi

    if [ ! -f $DEST_IMAGE ]; then
        echo " - ${DEST_IMAGE##*/}"
        gm convert "$SOURCE_IMAGE" "$DEST_IMAGE"
    fi

    if [ "png" == ${IMAGE_DISP_EXT} ]; then
        # PNG is fairly fast to decode so use that as source
        local CONV="$DEST_IMAGE"
    else
        local CONV="$SRC_IMAGE"
    fi

    if [ ! -f $WHITE_IMAGE ]; then
        echo " - ${WHITE_IMAGE##*/}"
        gm convert "$CONV" -black-threshold 255,255,255 -white-threshold 254,254,254 -negate -fill \#FF0000 -opaque black -transparent white -colors 2 "$WHITE_IMAGE"
    fi

    if [ ! -f $BLACK_IMAGE ]; then
        echo " - ${BLACK_IMAGE##*/}"
        gm convert "$CONV" -black-threshold 1,1,1 -white-threshold 0,0,0 -fill \#0000FF -opaque black -transparent white -colors 2 "$BLACK_IMAGE"
    fi

    if [ ! -f $PRESENTATION_IMAGE ]; then
        echo " - ${PRESENTATION_IMAGE##*/}"
        $PRESENTATION_SCRIPT "$CONV" "$PRESENTATION_IMAGE"
    fi

    if [ ! -f $HIST_IMAGE ]; then
        # Remove "-separate -append" to generate a RGB histogram
        # http://www.imagemagick.org/Usage/files/#histogram
        echo " - ${HIST_IMAGE##*/}"
        if [ "." == ".$CROP_PERCENT" ]; then
            convert "$CONV" -separate -append -define histogram:unique-colors=false -write histogram:mpr:hgram +delete mpr:hgram -negate -strip "$HIST_IMAGE"
        else
            convert "$CONV" -gravity Center -crop $CROP_PERCENT%x+0+0 -separate -append -define histogram:unique-colors=false -write histogram:mpr:hgram +delete mpr:hgram -negate -strip "$HIST_IMAGE"
        fi
    fi

    if [ "true" == "$FORCE_THUMBNAILS" -a -f "$THUMB_IMAGE" ]; then
        rm -f "$THUMB_IMAGE"
    fi
    if [ ! -f "$THUMB_IMAGE" ]; then
        echo " - ${THUMB_IMAGE##*/}"
        gm convert "$CONV" -sharpen 3 -enhance -resize $THUMB_IMAGE_SIZE "$THUMB_IMAGE"
    fi

}

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
        
        local SWIDTH=`echo "scale=6;$BWIDTH/$PWIDTH" | bc | sed 's/^\./0./'`
        # TODO: Seems like there is some mismatch going on here with some deliveries
        local SHEIGHT=`echo "scale=6;$BHEIGHT/$PHEIGHT" | bc | sed 's/^\./0./'`
#        SHEIGHT=`echo "scale=6;$BHEIGHT/$PWIDTH" | bc | sed 's/^\./0./'`
        local SHPOS=`echo "scale=6;$BHPOS/$PWIDTH" | bc | sed 's/^\./0./'`
        local SVPOS=`echo "scale=6;$BVPOS/$PHEIGHT" | bc | sed 's/^\./0./'`

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

# Generates overlays
# src dest altofile
# Output: ELEMENTS_HTML OVERLAYS OCR_CONTENT IDNEXT_CONTENT FULL_RELATIVE_HEIGHT
function processALTO() {
    local SRC=$1
    local DEST=$2
    local ALTO_FILE=$3
#    local WIDTH=$4
#    local HEIGHT=$5

    # Used by caller
    OVERLAYS=""
    ELEMENTS_HTML=""
    OCR_CONTENT=""

    local ALTO="${SRC_FOLDER}/${ALTO_FILE}"
    # TODO: Extract relevant elements from the Alto for display
    if [ ! -f $ALTO ]; then
        # TODO: Better handling of non-existence
            ELEMENTS_HTML="<p class=\"warning\">No ALTO file at $ALTO</p>"$'\n'
        return
    fi
    cp "$ALTO" "$DEST"
    # Extract key elements from the ALTO
    local ALTO_COMPACT=`cat "$ALTO_FILE" | sed ':a;N;$!ba;s/\\n/ /g'`
#    local PTAG=`echo "$ALTO_COMPACT" | grep -o "<PrintSpace[^>]\\+>"`
    local PTAG=`echo "$ALTO_COMPACT" | grep -o "<Page[^>]\\+>"`
    local PHEIGHT=`echo $PTAG | sed 's/.*HEIGHT=\"\([^"]\+\)".*/\\1/g'`
    local PWIDTH=`echo $PTAG | sed 's/.*WIDTH=\"\([^"]\+\)".*/\\1/g'`

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

    # Special overlays to show absolute black and absolute white pixels
    # The 2.0 is a hack as OpenSeaDragon scales with respect to width
    OVERLAYS="overlays: ["$'\n'
    OVERLAYS="${OVERLAYS}{id: 'white',"$'\n'
    OVERLAYS="${OVERLAYS}  x: 0.0, y: 0.0, width: 1.0, height: ${FULL_RELATIVE_HEIGHT},"$'\n'
    OVERLAYS="${OVERLAYS}  className: 'whiteoverlay'"$'\n'
    OVERLAYS="${OVERLAYS}},"$'\n'
    OVERLAYS="${OVERLAYS}{id: 'black',"$'\n'
    OVERLAYS="${OVERLAYS}  x: 0.0, y: 0.0, width: 1.0, height: ${FULL_RELATIVE_HEIGHT},"$'\n'
    OVERLAYS="${OVERLAYS}  className: 'blackoverlay'"$'\n'
    OVERLAYS="${OVERLAYS}},"$'\n'

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
    local ID=`echo $IMAGE | grep -o "[0-9][0-9][0-9][0-9]-.*"`
    
    if [ "." == ".$ID" ]; then
        echo "   Unable to extract ID for \"$IMAGE\""
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
    local UP=$1
    local PARENT=$2
    local SRC_FOLDER=$3
    local DEST_FOLDER=$4
    local IMAGE=$5
    local PREV_IMAGE=$6
    local NEXT_IMAGE=$7

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
    local PIDENTIFY=`identify "$PRESENTATION_IMAGE" | grep -o " [0-9]\+x[0-9]\\+ "`
    PRESENTATION_WIDTH=`echo $PIDENTIFY | grep -o "[0-9]\+x" | grep -o "[0-9]\+"`
    PRESENTATION_HEIGHT=`echo $PIDENTIFY | grep -o "x[0-9]\+" | grep -o "[0-9]\+"`
   
    if [ "true" == "$SKIP_EXISTING_PREVIEWS" -a -e "$P" ]; then
        return
    fi

    echo " - ${P##*/}"

    local ALTO_FILE="${BASE}${ALTO_EXT}"
    processALTO "$SRC_FOLDER" "$DEST_FOLDER" "$ALTO_FILE"
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

    local IHTML=`cat $IMAGE_TEMPLATE`
    IHTML=`template "$IHTML" "PARENT" "$PARENT"`
    local DATE=`date "+%Y-%m-%d %H:%M"`
    IHTML=`template "$IHTML" "DATE" "$DATE"`
    IHTML=`template "$IHTML" "UP" "$UP"`
    IHTML=`template "$IHTML" "NAVIGATION" "$NAVIGATION"`
    IHTML=`template "$IHTML" "BASE" "$BASE"`
    IHTML=`template "$IHTML" "SOURCE" "$SOURCE_IMAGE"`
    IHTML=`template "$IHTML" "FULL_RELATIVE_HEIGHT" "$FULL_RELATIVE_HEIGHT"`
    EDEST=${DEST_IMAGE##*/}
    IHTML=`template "$IHTML" "IMAGE" "$EDEST"`
    IHTML=`template "$IHTML" "IMAGE_WIDTH" "$IMAGE_WIDTH"`
    IHTML=`template "$IHTML" "IMAGE_HEIGHT" "$IMAGE_HEIGHT"`
    THUMB_LINK=${THUMB_IMAGE##*/}
    IHTML=`template "$IHTML" "THUMB" "$THUMB_LINK"`
    IHTML=`template "$IHTML" "THUMB_WIDTH" "$THUMB_WIDTH"`
    IHTML=`template "$IHTML" "THUMB_HEIGHT" "$THUMB_HEIGHT"`
    PRESENTATION_LINK=${PRESENTATION_IMAGE##*/}
    IHTML=`template "$IHTML" "PRESENTATION" "$PRESENTATION_LINK"`
    IHTML=`template "$IHTML" "PRESENTATION_WIDTH" "$PRESENTATION_WIDTH"`
    IHTML=`template "$IHTML" "PRESENTATION_HEIGHT" "$PRESENTATION_HEIGHT"`
    WHITE_LINK=${WHITE_IMAGE##*/}
    IHTML=`template "$IHTML" "WHITE" "$WHITE_LINK"`
    BLACK_LINK=${BLACK_IMAGE##*/}
    IHTML=`template "$IHTML" "BLACK" "$BLACK_LINK"`
    IHTML=`template "$IHTML" "OVERLAYS" "$OVERLAYS"`
    IHTML=`template "$IHTML" "OCR_CONTENT" "$OCR_CONTENT"`
    IHTML=`template "$IHTML" "IDNEXTS" "$IDNEXTS"`
    IHTML=`template "$IHTML" "IDPREVS" "$IDPREVS"`
    IHTML=`template "$IHTML" "ALTO_ELEMENTS_HTML" "$ELEMENTS_HTML"`
    EHIST=${HIST_IMAGE##*/}
    IHTML=`template "$IHTML" "HISTOGRAM" "$EHIST"`
    IHTML=`template "$IHTML" "ALTO" "$ALTO_FILE"`
    if [ "true" == "$RESOLVE_ALTERNATIVES" ]; then
        resolveAlternatives "$SRC_FOLDER" "$IMAGE"
        IHTML=`template "$IHTML" "ALTERNATIVES" "$ALTERNATIVES_HTML"`
    fi
    echo "$IHTML" > $P
 #    echo ""

#    cat $P
#    exit

 }

# up parent srcFolder dstFolder
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
    export -f makeImages
    echo "$IMAGES" | xargs -n 1 -I'{}' -P $THREADS bash -c 'makeImages "$@"' _ "$SRC_FOLDER" "$DEST_FOLDER" "{}" "$THUMB_IMAGE_SIZE" "$CROP_PERCENT" "$PRESENTATION_SCRIPT" \;

    # Generate pages
    local THUMBS_HTML=""
    local PREV_IMAGE=""
    if [ "." == ".$IMAGES" ]; then
        IMAGES_HTML="<p>No images</p>"$'\n'
    else
        IMAGES_HTML="<ul>"$'\n'
        for I in $IMAGES; do
            local NEXT_IMAGE=`echo "$IMAGES" | grep -A 1 "$I" | tail -n 1 | grep -v "$I"`
            makePreviewPage $UP $PARENT $SRC_FOLDER $DEST_FOLDER $I "$PREV_IMAGE" "$NEXT_IMAGE"
            IMAGES_HTML="${IMAGES_HTML}<li><a href=\"$PAGE_LINK\">$BASE</a></li>"$'\n'
            THUMBS_HTML="${THUMBS_HTML}<a class=\"thumblink\" href=\"$PAGE_LINK\"><img class=\"thumbimg\" src=\"${THUMB_LINK}\" alt=\"$BASE\" title=\"$BASE\" width=\"$THUMB_WIDTH\" height=\"$THUMB_HEIGHT\"/></a>"$'\n'
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

    local FHTML=`cat $FOLDER_TEMPLATE`
    FHTML=`template "$FHTML" "UP" "$UP"`
    FHTML=`template "$FHTML" "PARENT" "$PARENT"`
    FHTML=`template "$FHTML" "SRC_FOLDER" "$SRC_FOLDER"`
    FHTML=`template "$FHTML" "DEST_FOLDER" "$DEST_FOLDER"`
    FHTML=`template "$FHTML" "IMAGES_HTML" "$IMAGES_HTML"`
    FHTML=`template "$FHTML" "THUMBS_HTML" "$THUMBS_HTML"`
    FHTML=`template "$FHTML" "SUBFOLDERS_HTML" "$SUBFOLDERS_HTML"`
    FHTML=`template "$FHTML" "EDITION_HTML" "$EDITION_HTML"`
    echo "$FHTML" > $PP
    
#    cat $PP | grep -A 10 Images


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
