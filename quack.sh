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
# Quack 1.3 beta - Quality assurance tool for text scanning projects.
# 
# Generates zoomable (OpenSeadragon) views of scanned text pages with overlays
# containing OCR-text from ALTO-files. The views are static HTML pages that
# can be viewed directly from the file system or through a webserver.
#
# Note that the images used for OpenSeadragon are PNG.
# The focus is fully on QA, where pixel-perfect reproduction is required.
#
# The script supports iterative updates by re-using existing structures when 
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
export IMAGE_GLOB="*.tiff *.tif *.jp2 *.jpeg2000 *.j2k *.jpg *.jpeg"
# The extension of the ALTO files corresponding to the image files
# ALTO files are expected to be located next to the image files:
#   OurScanProject_batch_2013-09-18_page_007.tif
#   OurScanProject_batch_2013-09-18_page_007.alto.xml
export ALTO_EXT=".alto.xml"

# Sometimes the image corresponding to the ALTO has been scaled after ALTO
# generation. This factor will be multiplied to all ALTO elements. If the
# image has been scaled to half width & half height, set this to 0.5.
export ALTO_SCALE_FACTOR="1.0"

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

# Number of threads used for image processing. CPU and memory bound.
export THREADS=4

# Number of threads used for histograms. Note that histogram generation
# is very memory hungry (~2GB for a 30MP image), unless HISTOGRAM_PHEIGHT
# is set to a percentage.
export HISTOGRAM_THREADS=8

# Number of threads used for pages. Page generation uses very little memory and
# is almost exclusively CPU bound.
export PAGE_THREADS=8

# For production it is recommended that all FORCE_ options are set to "false" as
# it makes iterative updates fast. If quack settings are tweaked, the relevant
# FORCE_ options should be temporarily "true" until quack has been run once.

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
export RESOLVE_ALTERNATIVES=false

# If the IDNEXT attribute starts with 'ART' it is ignored
# Used to avoid visually linking everything on the page
export SKIP_NEXT_ART=false

# How much of the image to retain, cropping from center, when calculating
# histograms. Empty value = no crop. Valid values: 1-100
# This us usable for generating proper histograms for scans where the border
# is different from the rest of the image. Artifacts from rotations is an example.
# Suggested values are 85-95%.
export CROP_PERCENT=""

# If defined, all histograms will have a a fixed height of this percentage.
# If auto, histograms will scale individually to the highest value.
# If script_auto, histograms will scale as with auto, but will be generated by
# script (slow, low mem) instead of ImageMagick (fast, high mem).
# If auto is specified, it is highly recommended to decrease HISTOGRAM_THREADS
# to 2-4 on a 4-8GB machine
# Suggested values are 10-20%
# percentage or script_auto: scripted (low mem, slower)
# auto: GraphicsMagick (high mem, faster)
export HISTOGRAM_PHEIGHT="script_auto"

# If true, tiles are generated for OpenSeadragon. This requires Robert Barta's 
# deepzoom (see link in README.md) and will generate a lot of 260x260 pixel tiles.
# If false, a single image will be used with OpenSeadragon. This is a lot heavier
# on the browser but avoids the size and file-count overhead of the tiles.
export TILE="false"

# If true, a secondary view of the scans will be inserted into the page.
# The view represents an end-user version of the scan. This will often be 
# downscaled, levelled, sharpened and JPEG'ed.
export PRESENTATION="true"
# The image format for the presentation image. Possible values are png and jpg.
# jpg is recommended as this would normally be the choice for end-user presentation.
export PRESENTATION_IMAGE_DISP_EXT="jpg"

# Overlay colors for indicating burned out high- and low-lights
export OVERLAY_BLACK=3399FF
export OVERLAY_WHITE=FFFF00

# Limits for the overlays. Some scanners have absolute black as grey #02
# To get grey #02 and below marked as blown black, set BLOWN_BLACK_BT to 3,3,3
export BLOWN_WHITE_BT=255,255,255
export BLOWN_WHITE_WT=254,254,254
export BLOWN_BLACK_BT=1,1,1
export BLOWN_BLACK_WT=0,0,0

# Snippets are inserted verbatim at the top of the folder and the image pages.
# Use them for specifying things like delivery date or provider notes.
# Note that these snippet can be overridden on a per-folder and per-image basis
# by creating special files in the source tree (see SPECIFIC_FOLDER_SNIPPET and
# SPECIFIC_IMAGE_SNIPPET_EXTENSION below).
export SNIPPET_FOLDER=""
export SNIPPET_IMAGE=""

# End default settings. User-supplied overrides will be loaded from quack.settings

# If present in a source-folder, the content of the folder will be inserted into
# the generated folder HTML file.
export SPECIFIC_FOLDER_SNIPPET="folder.snippet"

# If a file with image basename + this extension is encountered, the content will
# be inserted into the generated image HTML file.
export SPECIFIC_IMAGE_SNIPPET_EXTENSION=".snippet"

# If no OpenSeadragon is present, the scripts attempts to download this version.
OSD_ZIP="openseadragon-bin-1.0.0.zip"
OSD_DIRECT="http://github.com/openseadragon/openseadragon/releases/download/v1.0.0/$OSD_ZIP"

# The blacklist and whitelist are files with regular expressions, used when traversing the 
# source folder. One expression/line.
export BLACKLIST="quack.blacklist"
export WHITELIST="quack.whitelist"

START_PATH=`pwd`
pushd `dirname $0` > /dev/null
export ROOT=`pwd`

if [ -e "quack.settings" ]; then
    echo "Sourcing user settings from quack.settings in `pwd`"
    source "quack.settings"
fi
if [ -e "$BLACKLIST" ]; then
    echo "Using $BLACKLIST in `pwd`"
    export BLACKLIST_FILE="`pwd`/$BLACKLIST"
fi
if [ -e "$WHITELIST" ]; then
    echo "Using $WHITELIST in `pwd`"
    export WHITELIST_FILE="`pwd`/$WHITELIST"
fi
# functions for generating identify-files and extract greyscale statistics
source "analyze.sh"
source "quack_helper_common.sh"
export PAGE_SCRIPT="`pwd`/quack_helper_imagepage.sh"
popd > /dev/null

# Local settings overrides general settings
if [ ! "$START_PATH" == "$ROOT" ]; then
    if [ -e "quack.settings" ]; then
        echo "Sourcing user settings from quack.settings in `pwd`"
        source "quack.settings"
    fi
    if [ -e "$BLACKLIST" ]; then
        echo "Using $BLACKLIST in `pwd`"
        export BLACKLIST_FILE="`pwd`/$BLACKLIST"
    fi
    if [ -e "$WHITELIST" ]; then
        echo "Using $WHITELIST in `pwd`"
        export WHITELIST_FILE="`pwd`/$WHITELIST"
    fi
fi

if [ ".true" == ".$FORCE_BLOWN" ]; then
    # When we force regeneration of blown, we must also regenerate the blown thumbs.
    export FORCE_BLOWN_THUMBS=true
fi

PRESENTATION_SCRIPT="$ROOT/presentation.sh"
if [ -f "$START_PATH/presentation.sh" ]; then
    echo "Using presentation.sh located in $START_PATH"
    PRESENTATION_SCRIPT="$START_PATH/presentation.sh"
fi
export FOLDER_TEMPLATE="$ROOT/web/folder_template.html"
export IMAGE_TEMPLATE="$ROOT/web/image_template.html"
export IMAGELINK_TEMPLATE="$ROOT/web/imagelink_template.html"
export THUMB_TEMPLATE="$ROOT/web/thumb_template.html"
export HIST_TEMPLATE="$ROOT/web/histogram_template.html"
DRAGON="openseadragon.min.js"

export PAGE_COUNTER=`createCounter page 0`
export IMAGE_COUNTER=`createCounter image 0`
export HIST_COUNTER=`createCounter histogram 0`

function usage() {
    echo "quack 1.2 beta - Quality Assurance oriented ALTO viewer"
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
pushd "$SOURCE" > /dev/null
SOURCE_FULL=`pwd`
popd > /dev/null

DEST=$2
if [ "." == ".$DEST" ]; then
    echo "Error: Missing destination" >&2
    echo ""
    usage
    exit 2
fi
if [ ! -f "$ROOT/web/$DRAGON" ]; then
    if [ -f "$ROOT/$DRAGON" ]; then
        echo "Copying $DRAGON from Quack root to the web folder"
        cp "$ROOT/$DRAGON" "$ROOT/web/"
    else
        echo "The file $ROOT/$DRAGON or $ROOT/web/$DRAGON does not exist" >&2
        if [ "." == ".`which wget`" -o "." == ".`which unzip`" ]; then
            echo "Please download it at http://openseadragon.github.io/#download" >&2
            echo "Tested version is 1.0.0, which can be downloaded from" >&2
            echo "$OSD_DIRECT" >&2
            exit
        else
            echo "Attempting to download of OpenSeadragon from" >&2
            echo "$OSD_DIRECT"
            wget "$OSD_DIRECT" -O "$ROOT/web/$OSD_ZIP"
            pushd "$ROOT/web" > /dev/null
            unzip "$ROOT/web/$OSD_ZIP"
            mv "openseadragon-bin-1.0.0/openseadragon.min.js" "$DRAGON"
            mv "openseadragon-bin-1.0.0/images" "$ROOT/web"
            rm -r "openseadragon-bin-1.0.0"
            popd > /dev/null
            rm "$ROOT/web/$OSD_ZIP"
            if [ ! -f "$ROOT/web/$DRAGON" ]; then
                echo "Automatic OpenSeadragon download and installation failed." >&2
                echo "Please download it at http://openseadragon.github.io/#download" >&2
                echo "Tested version is 1.0.0, which can be downloaded from" >&2
                echo "$OSD_DIRECT" >&2
                exit 2
            fi
            echo "Automatic download and installation of OpenSeadragon successful."
        fi
    fi
fi

# Copy OpenSeadragon and all css-files to destination
function copyFiles () {
    if [ ! -d "$DEST" ]; then
        echo "Creating folder $DEST"
        mkdir -p "$DEST"
    fi
    cp -r ${ROOT}/web/*.js ${ROOT}/web/*.css ${ROOT}/web/images "$DEST"
}

# http://stackoverflow.com/questions/14434549/how-to-expand-shell-variables-in-a-text-file
# Input: template-file
function ctemplate() {
    TMP="`mktemp`.sh"
    echo 'cat <<END_OF_TEXT' >  $TMP
    cat  "$1"                >> $TMP
    echo 'END_OF_TEXT'       >> $TMP
    . $TMP
    rm $TMP
}

# Creates the bash environment variables corresponding to those used by makeImages
# This is used to separate HTML generation from the actual image processing
# srcFolder dstFolder image
# Output: SOURCE_IMAGE DEST_IMAGE HIST_IMAGE THUMB
function makeImageParams() {
    local SRC_FOLDER="$1"
    local DEST_FOLDER="$2"
    local IMAGE="$3"

    local SANS_PATH=${IMAGE##*/}
    local BASE=${SANS_PATH%.*}

    # Used by function caller
    # Must be mirrored in makeImages
    SOURCE_IMAGE="${SRC_FOLDER}/${IMAGE}"
    DEST_IMAGE="${DEST_FOLDER}/${BASE}.${IMAGE_DISP_EXT}"
    HIST_IMAGE="${DEST_FOLDER}/${BASE}.histogram.png"
    HISTOGRAM_LINK=${HIST_IMAGE##*/}
    THUMB_IMAGE="${DEST_FOLDER}/${BASE}.thumb.jpg"
    THUMB_LINK=${THUMB_IMAGE##*/}
    WHITE_IMAGE="${DEST_FOLDER}/${BASE}.white.png"
    BLACK_IMAGE="${DEST_FOLDER}/${BASE}.black.png"
    PRESENTATION_IMAGE="${DEST_FOLDER}/${BASE}.presentation.jpg"
    TILE_FOLDER="${DEST_FOLDER}/${BASE}_files"
    PRESENTATION_TILE_FOLDER="${DEST_FOLDER}/${BASE}.presentation_files"
    ALTO_DEST="${DEST_FOLDER}/${BASE}.alto.xml"
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
    local SRC_FOLDER="$1"
    local DEST_FOLDER="$2"
    local IMAGE="$3"
    local CROP_PERCENT="$5"
    local PRESENTATION_SCRIPT="$6"
    local TILE="$7"

#    echo "makeImages $SRC_FOLDER $DEST_FOLDER"

    local SANS_PATH=${IMAGE##*/}
    local BASE=${SANS_PATH%.*}

    # Must mirror the ones in makeImageParams
    # Do not cheat by calling makeImageParams as makeImages might
    # be called in parallel
    local SOURCE_IMAGE="${SRC_FOLDER}/${IMAGE}"
    local DEST_IMAGE="${DEST_FOLDER}/${BASE}.${IMAGE_DISP_EXT}"
    local HIST_IMAGE="${DEST_FOLDER}/${BASE}.histogram.png"
    local HISTOGRAM_LINK=${HIST_IMAGE##*/}
    local THUMB_IMAGE="${DEST_FOLDER}/${BASE}.thumb.jpg"
    local THUMB_LINK=${THUMB_IMAGE##*/}
    local WHITE_IMAGE="${DEST_FOLDER}/${BASE}.white.png"
    local BLACK_IMAGE="${DEST_FOLDER}/${BASE}.black.png"
    local THUMB_OVERLAY_WHITE="${DEST_FOLDER}/${BASE}.white.thumb.png"
    local THUMB_OVERLAY_BLACK="${DEST_FOLDER}/${BASE}.black.thumb.png"
    local PRESENTATION_IMAGE="${DEST_FOLDER}/${BASE}.presentation.jpg"
    local TILE_FOLDER="${DEST_FOLDER}/${BASE}_files"
    local PRESENTATION_TILE_FOLDER="${DEST_FOLDER}/${BASE}.presentation_files"
    local ALTO_DEST="${DEST_FOLDER}/${BASE}.alto.xml"

    if [ ! -f "$SOURCE_IMAGE" ]; then
        echo "The source image $S does not exists" >&2
        exit
    fi

    local CREATED_IMAGES=`addGetCounter $IMAGE_COUNTER`

    # Even if TILE="true", we create the full main presentational image as it
    # might be requested for download
    if shouldGenerate "$FORCE_QAIMAGE" "$DEST_IMAGE" "QA (${CREATED_IMAGES}/${TOTAL_IMAGES})"; then
        gm convert "$SOURCE_IMAGE" -quality $IMAGE_DISP_QUALITY "$DEST_IMAGE"
    fi

    if [ "png" == ${IMAGE_DISP_EXT} ]; then
        # PNG is fairly fast to decode so use that as source
        local CONV="$DEST_IMAGE"
    else
        local CONV="$SOURCE_IMAGE"
    fi

    if [ ".true" == ".$PRESENTATION" ]; then
        if shouldGenerate "$FORCE_PRESENTATION" "$PRESENTATION_IMAGE" "presentation"; then
            $PRESENTATION_SCRIPT "$CONV" "$PRESENTATION_IMAGE"
        fi
    fi

    if [ ".true" == ".$TILE" ]; then
        if shouldGenerate "$FORCE_TILES" "$TILE_FOLDER" "tiles"; then
       # TODO: Specify JPEG quality
            deepzoom "$CONV" -format $IMAGE_DISP_EXT -path "${DEST_FOLDER}/"
        fi

        if [ ".true" == ".$PRESENTATION" ]; then
            if shouldGenerate "$FORCE_TILES" "$PRESENTATION_TILE_FOLDER" "presentation tiles"; then
                if [ ! -f "$PRESENTATION_IMAGE" ]; then
                    echo "Error: The image $PRESENTATION_IMAGE does not exist"
                else
        # TODO: Specify JPEG quality
                    deepzoom "$PRESENTATION_IMAGE" -format $PRESENTATION_IMAGE_DISP_EXT -path "${DEST_FOLDER}/"
                fi
            fi
        fi
    fi

    if shouldGenerate "$FORCE_BLOWN" "$WHITE_IMAGE" "overlay"; then
        gm convert "$CONV" -black-threshold $BLOWN_WHITE_BT -white-threshold $BLOWN_WHITE_WT -negate -fill \#$OVERLAY_WHITE -opaque black -transparent white -colors 2 "$WHITE_IMAGE"
    fi

    if shouldGenerate "$FORCE_BLOWN" "$BLACK_IMAGE" "overlay"; then
        gm convert "$CONV" -black-threshold $BLOWN_BLACK_BT -white-threshold $BLOWN_BLACK_WT -fill \#$OVERLAY_BLACK -opaque black -transparent white -colors 2 "$BLACK_IMAGE"
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

# Histogram generation is separated from generic image generation as it takes a lot of memory
# srcFolder dstFolder image crop presentation_script tile
function makeHistograms() {
    local SRC_FOLDER="$1"
    local DEST_FOLDER="$2"
    local IMAGE="$3"
    local CROP_PERCENT="$5"
    local PRESENTATION_SCRIPT="$6"
    local TILE="$7"

#    echo "makeImages $SRC_FOLDER $DEST_FOLDER"

    local SANS_PATH=${IMAGE##*/}
    local BASE=${SANS_PATH%.*}

    local DEST_IMAGE="${DEST_FOLDER}/${BASE}.${IMAGE_DISP_EXT}"
    local SOURCE_IMAGE="${SRC_FOLDER}/${IMAGE}"

    # Must mirror the ones in makeImageParams
    # Do not cheat by calling makeImageParams as makeImages might
    # be called in parallel
    local HIST_IMAGE="${DEST_FOLDER}/${BASE}.histogram.png"

    if [ ! -f "$SOURCE_IMAGE" ]; then
        echo "The source image $S does not exists" >&2
        exit
    fi

    local CREATED_HIST=`addGetCounter $HIST_COUNTER`

    if [ "png" == ${IMAGE_DISP_EXT} ]; then
        # PNG is fairly fast to decode so use that as source
        local CONV="$DEST_IMAGE"
    else
        local CONV="$SOURCE_IMAGE"
    fi

    if shouldGenerate "$FORCE_HISTOGRAM" "$HIST_IMAGE" "histogram (${CREATED_HIST}/${TOTAL_IMAGES})"; then
        if [ "." == ".$HISTOGRAM_PHEIGHT" -o "auto" == "$HISTOGRAM_PHEIGHT" ]; then
            # Remove "-separate -append" to generate a RGB histogram
            # http://www.imagemagick.org/Usage/files/#histogram
            if [ "." == ".$CROP_PERCENT" ]; then
                convert "$CONV" -separate -append -define histogram:unique-colors=false -write histogram:mpr:hgram +delete mpr:hgram -negate -strip "$HIST_IMAGE"
            else
                convert "$CONV" -gravity Center -crop $CROP_PERCENT%x+0+0 -separate -append -define histogram:unique-colors=false -write histogram:mpr:hgram +delete mpr:hgram -negate -strip "$HIST_IMAGE"
            fi
        else
            histogramScript "$CONV" 200 false "$HIST_IMAGE"
        fi
    fi
}
export -f makeHistograms

# Input: [recursive]
# Output: Images in the current folder, matching $IMAGE_GLOB and
# obeying white- and black-list.
function listImages() {
    local RECURSIVE="$1"

    if [ -n "$BLACKLIST_FILE" ]; then
        if [ -n "$WHITELIST_FILE" ]; then
            ls $IMAGE_GLOB 2> /dev/null | grep -f "$WHITELIST_FILE" | grep -v -f "$BLACKLIST_FILE"
        else
            ls $IMAGE_GLOB 2> /dev/null | grep -v -f "$BLACKLIST_FILE"
        fi
    else
        if [ -n "$WHITELIST_FILE" ]; then
            ls $IMAGE_GLOB 2> /dev/null | grep -f "$WHITELIST_FILE"
        else
            ls $IMAGE_GLOB 2> /dev/null
        fi
    fi

    if [ ".true" == ".$RECURSIVE" ]; then
        for SUB in `ls -d */ 2> /dev/null`; do
            pushd $SUB > /dev/null
            listImages $RECURSIVE
            popd > /dev/null
        done
    fi
}

# Input: up parent srcFolder dstFolder
#
function makeIndex() {
    local UP="$1"
    local PARENT="$2"
    local SRC_FOLDER="$3"
    local DEST_FOLDER="$4"
#    echo "Processing level '$PARENT' from $SRC_FOLDER"

    if [ ! -d "$SRC_FOLDER" ]; then
        echo "Unable to locate folder $SRC_FOLDER from `pwd`" >&2
        exit
    fi
    pushd "$SRC_FOLDER" > /dev/null
    local SRC_FOLDER=`pwd`
    popd > /dev/null
    echo "Processing $SRC_FOLDER"

    if [ ! -d "$DEST_FOLDER" ]; then
#        echo "Creating folder $DEST_FOLDER"
        mkdir -p "$DEST_FOLDER"
    fi
    pushd "$DEST_FOLDER" > /dev/null
    local DEST_FOLDER=`pwd`
    popd > /dev/null

    pushd "$SRC_FOLDER" > /dev/null
    local PP="${DEST_FOLDER}/index.html"

    if [ "." == ".$PARENT" ]; then
        true
#        echo "<p>Parent: N/A</p>" >> $PP
    fi

    # Images
    local IMAGES=`listImages`

    # Generate graphics
    # http://stackoverflow.com/questions/11003418/calling-functions-with-xargs-within-a-bash-script
    echo "$IMAGES" | xargs -n 1 -I'{}' -P $THREADS bash -c 'makeImages "$@"' _ "$SRC_FOLDER" "$DEST_FOLDER" "{}" "$THUMB_IMAGE_SIZE" "$CROP_PERCENT" "$PRESENTATION_SCRIPT" "$TILE" \;

    # Generate histograms
    echo "$IMAGES" | xargs -n 1 -I'{}' -P $HISTOGRAM_THREADS bash -c 'makeHistograms "$@"' _ "$SRC_FOLDER" "$DEST_FOLDER" "{}" "$THUMB_IMAGE_SIZE" "$CROP_PERCENT" "$PRESENTATION_SCRIPT" "$TILE" \;

    # Generate pages
    echo "$IMAGES" | xargs -n 1 -I'{}' -P $PAGE_THREADS bash -c '$PAGE_SCRIPT "$@"' _ "$UP" "$PARENT" "$SRC_FOLDER" "$DEST_FOLDER" "{}" "$IMAGES" \;

#    if [ ! "." == ".$IMAGES" ]; then
#        for I in $IMAGES; do
#            makePreviewPage "$UP" "$PARENT" "$SRC_FOLDER" "$DEST_FOLDER" "$I" "$IMAGES"
            #"$PREV_IMAGE" "$NEXT_IMAGE"
#        done
#    fi

    # Generate links, thumbs and histograms from the pages for the folder view
    local THUMBS_HTML=""
    local HISTOGRAMS_HTML=""
    local ILIST_HTML=""
    if [ "." == ".$IMAGES" ]; then
        local THUMBS_HTML="<p>No images</p>"$'\n'
        local HISTOGRAMS_HTML="<p>No images</p>"$'\n'
    else
        for I in $IMAGES; do
            local SANS_PATH=${I##*/}
            local BASE=${SANS_PATH%.*}
            # Must be kept in sync with quack_helper_imagepage
            local ILINK="${DEST_FOLDER}/${BASE}.link.html"
            local TLINK="${DEST_FOLDER}/${BASE}.thumb.html"
            local HLINK="${DEST_FOLDER}/${BASE}.hist.html"
            local ILIST_HTML="${ILIST_HTML}`cat \"$ILINK\"`"$'\n'
            local THUMBS_HTML="${THUMBS_HTML}`cat \"$TLINK\"`"$'\n'
            local HISTOGRAMS_HTML="${HISTOGRAMS_HTML}`cat \"$HLINK\"`"$'\n'
        done
    fi

    local SUBS=`ls "$SRC_FOLDER"`
    if [ "." == ".$S
    UBS" ]; then
        SUBFOLDERS_HTML="<p>No subfolders</p>"$'\n'
    else
        SUBFOLDERS_HTML="<ul>"$'\n'
        # TODO: Make the iterator handle spaces
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

    pushd $SRC_FOLDER > /dev/null
    if [ -f $SPECIFIC_FOLDER_SNIPPET ]; then
        SNIPPET=`cat $SPECIFIC_FOLDER_SNIPPET`
    else
        SNIPPET="$SNIPPET_FOLDER"
    fi
    popd > /dev/null

    # UP, PARENT, SRC_FOLDER, DEST_FOLDER, ILIST_HTML, THUMBS_HTML, HISTOGRAMS_HTML, SUBFOLDERS_HTML, EDITION_HTML, SNIPPET
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
pushd "$SOURCE" > /dev/null
export TOTAL_IMAGES=`listImages true | wc -l`
popd > /dev/null
makeIndex "" "" "$SOURCE" "$DEST"
deleteCount $PAGE_COUNTER
deleteCount $IMAGE_COUNTER
deleteCount $HIST_COUNTER
echo "All done at `date`"
echo "Please open ${DEST}/index.html in a browser"
