#!/bin/bash

#
# Generates presentational copies for scanned pages.
# Intended to be called from quack.sh to generate images to shown on the QA page.
#
# Override settings by creating "presentation.settings" and specifying DEFAULT_COMMANDS
# and/or get_commands
#

SETTINGS="presentation.settings"

# geometry resizes to 50% (the > is redundant with percents <= 100, but we keep it
# as it is a fine default as we never want to enlarge).
# unsharp is for a high quality 300 DPI scan with no previous sharpen applied.
# level is highly source-specific. The default is a conservative starker contrast.
# no intensities > 240.
# Quality is for JPEG output. This needs to be quite high as JPEG artifacts are
# very visible with tiny text.
DEFAULT_COMMANDS="-geometry 50%x> -unsharp 0.8x0.1+0.8+2.0 -level 10,1.0,245 -quality 90"

# Input: source
# Output: COMMANDS (GraphicsMagick options)
function get_commands() {
    local SOURCE="$1"

    if [ "." != ".`echo \"$SOURCE\" | grep -o inesta`" ]; then
        # This provider has very dark scans with no intensities > 240
        COMMANDS="-geometry 50%x> -unsharp 0.8x0.1+0.8+2.0 -level 0,1.0,230 -quality 90"
        return
    fi
    if [ "." != ".`echo \"$SOURCE\" | grep -o pex`" ]; then
        # This provider has scans practically without any blown high- or low-lights
        COMMANDS="-geometry 50%x> -unsharp 0.8x0.1+0.8+2.0 -level 15,1.0,240 -quality 90"
        return
    fi
    COMMANDS="$DEFAULT_COMMANDS"
}

pushd `dirname $0` > /dev/null
ROOT=`pwd`
if [ -e "$SETTINGS" ]; then
    echo "Sourcing settings from $SETTINGS"
    source "$SETTINGS"
fi
popd > /dev/null

SOURCE="$1"
DESTINATION="$2"

if [ ! -f "$SOURCE" ]; then
    echo "The image '$SOURCE' does not exist"
    exit 2
fi

if [ "." == ".$DESTINATION" ]; then
    echo "Usage: ./presentation.sh source destination"
    exit 2
fi

get_commands "$SOURCE"
gm convert "$SOURCE" $COMMANDS "$DESTINATION"
