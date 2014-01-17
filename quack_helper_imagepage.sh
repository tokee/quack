#!/bin/bash

#
# Creates a HTML page representing a single image.
# The image files used by this function must be created (function makeImages) before calling
# makePreviewPage.
#
# Input: up parent srcFolder dstFolder image prev_image next_image
# Output: PAGE_LINK BASE THUMB_LINK THUMB_WIDTH THUMB_HEIGHT HISTOGRAM_LINK HISTOGRAM_WIDTH HISTOGRAM_HEIGHT ILINK
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

    makeImageParams "$SRC_FOLDER" "$DEST_FOLDER" "$IMAGE"

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
   
    if [ "true" != "$FORCE_PAGES" -a -e "$P" ]; then
        return
    fi
    
    CREATED_PAGES=$((CREATED_PAGES+1))
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

    # image stats
#    grey_stats "$IMAGE"
    # TODO: Use destination if that is lossless and faster to open?
    local GREY=`grey_stats "$SOURCE_IMAGE"`

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
    local GREY_ALL_SOURCE=`im_identify "$SOURCE_IMAGE"`
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
export -f makePreviewPage
