#!/bin/bash

#
# Functions used by different quack scripts
#

# Input: id initialValue
# Output: lockname
function createCounter() {
    local ID="$1"
    local INITIAL="$2"
    pushd `dirname $0` > /dev/null
    local LOCKNAME="`pwd`/lock.${ID}_$$"
    popd > /dev/null
    local COUNTFILE="${LOCKNAME}.counter"
    if [ "." == ".$INITIAL" ]; then
        local INITIAL=1
    fi
    echo "$INITIAL" > $COUNTFILE
    echo "$LOCKNAME"
}
export -f createCounter

# Input: lockname
# Output: Old counter from lock file + 1
function addGetCounter() {
    local LOCKNAME="$1"
    if [ "." == ".$LOCKNAME" ]; then
        echo "threadedCounter: The lockname must be specified" 1>&2
        exit
    fi
    local COUNTFILE="${LOCKNAME}.counter"

    # http://stackoverflow.com/questions/8231847/bash-script-to-count-number-of-times-script-has-run
    mkdir $LOCKNAME 2> /dev/null
    while [[ $? -ne 0 ]] ; do
        sleep 0.1
        mkdir $LOCKNAME 2> /dev/null
    done
    local COUNTER=`cat "$COUNTFILE"`
    local COUNTER=$((COUNTER+1))
    echo $COUNTER > "$COUNTFILE"
    rm -rf $LOCKNAME
    echo $COUNTER
}
export -f addGetCounter

# Removed old count files
function deleteCount() {
    local LOCKNAME="$1"
    if [ "." == ".$LOCKNAME" ]; then
        echo "deleteCount: The lockname must be specified" 1>&2
        exit
    fi
    local COUNTFILE="${LOCKNAME}.counter"

    if [ -d "$LOCKNAME" ]; then
        rm -r "$LOCKNAME"
    fi
    if [ -f "$COUNTFILE" ]; then
        rm -r "$COUNTFILE"
    fi
}
export -f deleteCount

#L=`createCount foo 0`
#addGetCounter $L
#addGetCounter $L

# Skips the given number of lines and returns the rest
# Input: string lines
function skipLines() {
    local TEXT="$1"
    local SKIP="$2"
 
    local LENGTH=`echo "$TEXT" | wc -l`
    if [ $LENGTH -le $SKIP ]; then
        echo ""
        return
    fi
    echo "$TEXT" | tail -n $((LENGTH-SKIP))

}
export -f skipLines

#skipLines "$1" "$2"
