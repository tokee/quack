#!/bin/bash

# Get helper functions
pushd `dirname $0` > /dev/null
source "analyze.sh"
source "quack_helper_common.sh"
popd > /dev/null

# TODO: Double-defined in quack.sh. Move to common script
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

# Searches from the root for alternative versions of the given image
# Very specific to Statsbiblioteket
# src_folder image
# Output: ALTERNATIVES_HTML
function resolveAlternatives() {
    local SRC_FOLDER="$1"
    local IMAGE="$2"
    local FULL="${SRC_FOLDER}/${IMAGE}"
#    local ID=`echo "$IMAGE" | grep -o "[0-9][0-9][0-9][0-9]-.*"`
    local ID="${IMAGE%.*}"

    if [ "." == ".$ID" ]; then
        echo "   Unable to extract ID for \"$IMAGE\". No alternatives lookup"
        return
    fi

    pushd "$SOURCE_FULL" > /dev/null
    ALTERNATIVES_HTML="<ul class=\"alternatives\">"$'\n'
    for A in `find . -name "*${ID}" | sort`; do
        # "../../.././Apex/B3/2012-01-05-01/Dagbladet-2012-01-05-01-0130B.jp2 -> Apex/B3
       local LINK=`echo "$A" | sed 's/[./]\\+\\([^\\/]\\+\\/[^\\/]\\+\\).*/\\1/g'`
       local D="${A%.*}"
       ALTERNATIVES_HTML="${ALTERNATIVES_HTML}<li><a href=\"${UP}${D}.html\">${LINK}</a></li>"$'\n'
    done
    ALTERNATIVES_HTML="${ALTERNATIVES_HTML}</ul>"$'\n'
    popd > /dev/null
}

# Generates JavaScript snippet for black and white overlays
# Input: src
# Output: OVERLAYS (not terminated with ']')
function blackWhite() {
    local SRC="$1"
    local IMAGE_WIDTH=$2
    local IMAGE_HEIGHT=$3
    local REL_HEIGHT=`echo "scale=2;$IMAGE_HEIGHT/$IMAGE_WIDTH" | bc`

    if [ "." == ".$CROP_PERCENT" ]; then
        local CROP_X_FRACTION="0.0"
        local CROP_Y_FRACTION="0.0"
        local CROP_WIDTH_FRACTION="1.0"
        local CROP_HEIGHT_FRACTION="$REL_HEIGHT"
    else
        local PERCENT=`echo "$CROP_PERCENT" | grep -o "[0-9]\+"`
        # TODO: Rounding is quite rough. Consider keeping fractions and skipping intermediates
        local PERCENT=$(((100-$PERCENT)/2))
        local CROP_X=$((PERCENT*IMAGE_WIDTH/100))
        local CROP_Y=$((PERCENT*IMAGE_HEIGHT/100))
        local CROP_WIDTH=$((IMAGE_WIDTH-(2*CROP_X)))
        local CROP_HEIGHT=$((IMAGE_HEIGHT-(2*CROP_Y)))
        local CROP_X_FRACTION=`echo "scale=2;x=$CROP_X/$IMAGE_WIDTH; if(x<1) print 0; x" | bc`
        local CROP_Y_FRACTION=`echo "scale=2;x=$CROP_Y/$IMAGE_WIDTH; if(x<1) print 0; x" | bc`
        local CROP_WIDTH_FRACTION=`echo "scale=2;x=$CROP_WIDTH/$IMAGE_WIDTH; if(x<1) print 0; x" | bc`
        local CROP_HEIGHT_FRACTION=`echo "scale=2;x=$CROP_HEIGHT/$IMAGE_WIDTH; if(x<1) print 0; x" | bc`
    fi

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
    OVERLAYS="${OVERLAYS}{id: 'cropbox',"$'\n'
    OVERLAYS="${OVERLAYS}  x: $CROP_X_FRACTION, y: $CROP_Y_FRACTION, width: $CROP_WIDTH_FRACTION, height: $CROP_HEIGHT_FRACTION,"$'\n'
    OVERLAYS="${OVERLAYS}  className: 'cropoverlay'"$'\n'
    OVERLAYS="${OVERLAYS}},"$'\n'
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
    IDNEXT_CONTENT=""
    FULL_RELATIVE_HEIGHT="1"
    ACCURACY="N/A"

    local ALTO="${SRC_FOLDER}/${ALTO_FILE}"
    blackWhite "$SRC" $IMAGE_WIDTH $IMAGE_HEIGHT
    # TODO: Extract relevant elements from the Alto for display
    if [ ! -f "$ALTO" ]; then
        # TODO: Better handling of non-existence
            ELEMENTS_HTML="<p class=\"warning\">No ALTO file at $ALTO</p>"$'\n'
            # Terminate the black/white overlay and return
            OVERLAYS="${OVERLAYS}]"
        return
    fi
    
    cp "$ALTO" "$ALTO_DEST"
    # Extract key elements from the ALTO
    local ALTO_COMPACT=`cat "$ALTO_FILE" | sed ':a;N;$!ba;s/\\n/ /g'`
#    local PTAG=`echo "$ALTO_COMPACT" | grep -o "<PrintSpace[^>]\\+>"`
    local PTAG=`echo "$ALTO_COMPACT" | grep -o "<Page[^>]\\+>"`
    local PHEIGHT=`echo $PTAG | sed 's/.*HEIGHT=\"\([^"]\+\)".*/\\1/g'`
    local PWIDTH=`echo $PTAG | sed 's/.*WIDTH=\"\([^"]\+\)".*/\\1/g'`
    ACCURACY=`echo $PTAG | sed 's/.*PC=\"\([^"]\+\)".*/\\1/g'`
    ACCURACY=`echo "scale=2;x=$ACCURACY*100/1; if(x<1) print 0; x" | bc`

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
    SANS=`cat "$ALTO" | sed ':a;N;$!ba;s/\\n/ /g'`

    processElements "$SANS" "ComposedBlock" "composed"
    processElements "$SANS" "Illustration" "illustration"
    processElements "$SANS" "TextBlock" "highlight"

    OVERLAYS="${OVERLAYS}   ]"$'\n'
}

#
# Creates a HTML page representing a single image.
# The image files used by this function must be created (function makeImages) before calling
# makePreviewPage.
#
# Input: up parent srcFolder dstFolder image images
# Output: PAGE_LINK BASE THUMB_LINK THUMB_WIDTH THUMB_HEIGHT HISTOGRAM_LINK HISTOGRAM_WIDTH HISTOGRAM_HEIGHT ILINK
function makePreviewPage() {
    local UP="$1"
    local PARENT="$2"
    local SRC_FOLDER="$3"
    local DEST_FOLDER="$4"
    local IMAGE="$5"
    local IMAGES="$6"

    local PREV_IMAGE=`echo "$IMAGES" | grep -B 1 "$IMAGE" | head -n 1 | grep -v "$IMAGE"`
    local NEXT_IMAGE=`echo "$IMAGES" | grep -A 1 "$IMAGE" | tail -n 1 | grep -v "$IMAGE"`

    local SANS_PATH=${IMAGE##*/}
    BASE=${SANS_PATH%.*}
    P="${DEST_FOLDER}/${BASE}.html"

    # Must be synced with quack.makeImageParams()
    local SOURCE_IMAGE="${SRC_FOLDER}/${IMAGE}"
    local DEST_IMAGE="${DEST_FOLDER}/${BASE}.${IMAGE_DISP_EXT}"
    local HIST_IMAGE="${DEST_FOLDER}/${BASE}.histogram.png"
    local HISTOGRAM_LINK=${HIST_IMAGE##*/}
    local THUMB_IMAGE="${DEST_FOLDER}/${BASE}.thumb.jpg"
    local THUMB_LINK=${THUMB_IMAGE##*/}
    local WHITE_IMAGE="${DEST_FOLDER}/${BASE}.white.png"
    local BLACK_IMAGE="${DEST_FOLDER}/${BASE}.black.png"
    local PRESENTATION_IMAGE="${DEST_FOLDER}/${BASE}.presentation.jpg"
    local TILE_FOLDER="${DEST_FOLDER}/${BASE}_files"
    local PRESENTATION_TILE_FOLDER="${DEST_FOLDER}/${BASE}.presentation_files"
    local ALTO_DEST="${DEST_FOLDER}/${BASE}.alto.xml"

    # Must be kept in sync with quack.makeIndex()
    local ILINK="${DEST_FOLDER}/${BASE}.link.html"
    local TLINK="${DEST_FOLDER}/${BASE}.thumb.html"
    local HLINK="${DEST_FOLDER}/${BASE}.hist.html"

    local SSNIP="${BASE}${SPECIFIC_IMAGE_SNIPPET_EXTENSION}"

    if [ -f $SSNIP ]; then
        SNIPPET=`cat $SSNIP`
    else
        SNIPPET="$SNIPPET_FOLDER"
    fi

    # Used by function caller
    PAGE_LINK="${BASE}.html"

#    makeImageParams "$SRC_FOLDER" "$DEST_FOLDER" "$IMAGE"

    if [ ! -e "$DEST_IMAGE" ]; then
        echo "The destination image '$DEST_IMAGE' for '$IMAGE' has not been created" >&2
        exit
    fi

    local IDENTIFY=`identify "$DEST_IMAGE" | grep -o " [0-9]\+x[0-9]\\+ "`
    IMAGE_WIDTH=`echo $IDENTIFY | grep -o "[0-9]\+x" | grep -o "[0-9]\+"`
    IMAGE_HEIGHT=`echo $IDENTIFY | grep -o "x[0-9]\+" | grep -o "[0-9]\+"`
    IMAGE_MP=`echo "scale=1;x=$IMAGE_WIDTH*$IMAGE_HEIGHT/1000000; if(x<1) print 0; x" | bc`
    local TIDENTIFY=`identify "$THUMB_IMAGE" | grep -o " [0-9]\+x[0-9]\\+ "`
    THUMB_WIDTH=`echo $TIDENTIFY | grep -o "[0-9]\+x" | grep -o "[0-9]\+"`
    THUMB_HEIGHT=`echo $TIDENTIFY | grep -o "x[0-9]\+" | grep -o "[0-9]\+"`
    local HIDENTIFY=`identify "$HIST_IMAGE" | grep -o " [0-9]\+x[0-9]\\+ "`
    HISTOGRAM_WIDTH=`echo $HIDENTIFY | grep -o "[0-9]\+x" | grep -o "[0-9]\+"`
    HISTOGRAM_HEIGHT=`echo $HIDENTIFY | grep -o "x[0-9]\+" | grep -o "[0-9]\+"`

    if [ ".true" == ".$PRESENTATION" ]; then
        local PIDENTIFY=`identify "$PRESENTATION_IMAGE" | grep -o " [0-9]\+x[0-9]\\+ "`
        PRESENTATION_WIDTH=`echo $PIDENTIFY | grep -o "[0-9]\+x" | grep -o "[0-9]\+"`
        PRESENTATION_HEIGHT=`echo $PIDENTIFY | grep -o "x[0-9]\+" | grep -o "[0-9]\+"`
    fi
   
    local CREATED_PAGES=`addGetCounter $PAGE_COUNTER`

    if [ "true" != "$FORCE_PAGES" -a -e "$P" ]; then
        return
    fi

    echo " - ${P##*/} (${CREATED_PAGES}/${TOTAL_IMAGES})"

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

    # PARENT, DATE, UP, NAVIGATION, BASE, SOURCE, FULL_RELATIVE_HEIGHT, EDEST, IMAGE_WIDTH, IMAGE_HEIGHT, IMAGE_MP, TILE_SOURCES, THUMB, THUMB_WIDTH, THUMB_HEIGHT, PRESENTATION, PRESENTATION_WIDTH, PRESENTATION_HEIGHT, WHITE, BLACK, OVERLAYS, OCR_CONTENT, IDNEXTS, IDPREVS, ALTO_ELEMENTS_HTML, HISTOGRAM, ALTO, ALTERNATIVES
    SOURCE="$SOURCE_IMAGE"
    SOURCE_SHORT=${SOURCE##*/}
    SOURCE_SIZE=`du -k "$SOURCE" | grep -o "^[0-9]\+"`
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
        if [ ".true" == ".$PRESENTATION" ]; then
            PRESENTATION_TILE_SOURCES="      Image: {\
        xmlns:    \"http://schemas.microsoft.com/deepzoom/2008\",\
        Url:      \"${PRESENTATION_TILE_FOLDER##*/}/\",\
        Format:   \"$PRESENTATION_IMAGE_DISP_EXT\",\
        Overlap:  \"4\",\
        TileSize: \"256\",\
        Size: {\
          Width:  \"$PRESENTATION_WIDTH\",\
          Height: \"$PRESENTATION_HEIGHT\"\
        }\
      }"$'\n'
        else
            PRESENTATION_TILE_SOURCES=""
        fi
    else
        TILE_SOURCES="      type: 'legacy-image-pyramid',\
      levels:[\
        {\
          url: '${EDEST}',\
          width:  ${IMAGE_WIDTH},\
          height: ${IMAGE_HEIGHT}\
        }\
      ]"$'\n'
        if [ ".true" == ".$PRESENTATION" ]; then
            PRESENTATION_TILE_SOURCES="      type: 'legacy-image-pyramid',\
      levels:[\
        {\
          url: '${PRESENTATION_IMAGE##*/}',\
          width:  ${PRESENTATION_WIDTH},\
          height: ${PRESENTATION_HEIGHT}\
        }\
      ]"$'\n'
        else
            PRESENTATION_TILE_SOURCES=""
        fi
    fi
    THUMB="$THUMB_LINK"
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

    # TODO: Use destination if that is lossless and faster to open?
    local GREY=`grey_stats "$SOURCE_IMAGE" "$DEST_FOLDER"`

    # $PIXELS $UNIQUE $FIRST_COUNT $PERCENT_FIRST $FIRST_GREY $LAST_COUNT $PERCENT_LAST $LAST_GREY $COUNT_SPIKE $PERCENT_SPIKE $GREY_SPIKE $ZEROES $HOLES
    # 1000095 512 82362 8.23 (0,0,0) 255 .02 (255,255,255)
    GREY_PIXELS=`echo "$GREY" | cut -d\  -f1`
    GREY_UNIQUE=`echo "$GREY" | cut -d\  -f2`
    GREY_COUNT_FIRST=`echo "$GREY" | cut -d\  -f3`
    GREY_PERCENT_FIRST=`echo "$GREY" | cut -d\  -f4`
    GREY_FIRST=`echo "$GREY" | cut -d\  -f5`
    GREY_COUNT_LAST=`echo "$GREY" | cut -d\  -f6`
    GREY_PERCENT_LAST=`echo "$GREY" | cut -d\  -f7`
    GREY_LAST=`echo "$GREY" | cut -d\  -f8`
    GREY_COUNT_SPIKE=`echo "$GREY" | cut -d\  -f9`
    GREY_PERCENT_SPIKE=`echo "$GREY" | cut -d\  -f10`
    GREY_SPIKE=`echo "$GREY" | cut -d\  -f11`
    GREY_ZEROES=`echo "$GREY" | cut -d\  -f12`
    GREY_HOLES=`echo "$GREY" | cut -d\  -f13`
    local GREY_ALL_SOURCE=`im_identify "$SOURCE_IMAGE" "$DEST_FOLDER"`
    GREY_ALL=`cat "$GREY_ALL_SOURCE" | grep -A 256 Histogram | tail -n 256`

    ctemplate $IMAGE_TEMPLATE > $P
    ctemplate $IMAGELINK_TEMPLATE > $ILINK
    ctemplate $HIST_TEMPLATE > $HLINK
    ctemplate $THUMB_TEMPLATE > $TLINK

#    ls -l "$IMAGE"
#   echo "$GREY"
    # ***
 #    echo ""

#    cat $P
#    exit


 }
makePreviewPage "$@"
