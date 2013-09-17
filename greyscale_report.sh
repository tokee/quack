#!/bin/bash
TOPX=20
WEBROOT="http://pc254.sb.statsbiblioteket.dk/quack/tilbud2/"

LOG=$1
if [ "." == ".$LOG" ]; then
    echo "Usage: ./greyscale_report.sh logfile [html]"
    exit -1
fi
TYPE=$2
if [ "." != ".$TYPE" ]; then
    if [ "html" != "$TYPE" ]; then
        echo "The only valid type is html. $TYPE was specified"
        exit -1
    fi
fi

if [ "html" == "$TYPE" ]; then
    echo "<html>"
    echo "<head><title>Report for $LOG</title></head>"
    echo "<body>"
    echo "<h1>Report for $LOG with `cat $LOG | wc -l` analyzed images</h1>"
else 
    echo "Report for $LOG with `cat $LOG | wc -l` analyzed images"
fi
echo ""

# Stats for unique greyscales as well as brightest greyscale
if [ "html" == "$TYPE" ]; then
    echo "<h2>Distribution by number of unique greyscales</h2>"
    echo "<table>"
    echo "<tr><th>#occurrences</th> <th>#uniques</th> <th>brightest greyscale</th></tr>"
else
    echo "Distribution by number of unique greyscales"
    echo "#occurrences #uniques brightest_greyscale"
fi
# 1. Bucket #unique
UNIQUES=`cat "$LOG" | cut -d " " -f 3 | sort | uniq`
# 2. Extract brightest as well as count for each #unique
for U in $UNIQUES; do
    COUNT=`cat "$LOG" | cut -d " " -f 3,9 | grep "$U (" | wc -l`
    if [ "html" == "$TYPE" ]; then
        echo -n "<tr><td>$COUNT</td> <td>$U</td> <td>"
        echo -n `cat "$LOG" | cut -d " " -f 3,9 | grep "$U (" | cut -d " " -f 2 | sort -u`
        echo "</td></tr>"
    else
        echo -n "$COUNT $U "
        echo `cat "$LOG" | cut -d " " -f 3,9 | grep "$U (" | cut -d " " -f 2 | sort -u`
    fi
done
if [ "html" == "$TYPE" ]; then
    echo "</table>"
fi

echo ""
if [ "html" == "$TYPE" ]; then
    echo "<h2>Percent of image with darkest greyscale, top $TOPX</h2>"
    echo "<table>"
    echo "<tr><th>percent</th>  <th>darkest greyscale</th> <th>link</th></tr>"
else
    echo "Percent of image with darkest greyscale, top $TOPX"
fi
for P in `cat "$LOG" | cut -d " " -f 5 | sort -n -r | head -n $TOPX`; do
    LINE=`cat "$LOG" | cut -d " " -f 1,5,6 | grep " $P (" | cut -d " " -f 1,3 | head -n 1`
    if [ "html" == "$TYPE" ]; then
        C=`echo "$LINE" | cut -d " " -f 2`
        I=`echo "$LINE" | cut -d " " -f 1`
        REF=${I##*/}
        REF="${REF%.*}"
        LINK="$WEBROOT${I%.*}.html"

        echo "<tr><td>${P}%</td> <td>$C</td> <td><a href=\"$LINK\">$REF</a></td></td></tr>"
    else
        echo "${P}% `echo "$LINE" | cut -d " " -f 2` `echo "$LINE" | cut -d " " -f 1`"
    fi
done
if [ "html" == "$TYPE" ]; then
    echo "</table>"
fi

echo ""
if [ "html" == "$TYPE" ]; then
    echo "<h2>Percent of image with brightest greyscale, top $TOPX</h2>"
    echo "<table>"
    echo "<tr><th>percent</th>  <th>brightest greyscale</th> <th>link</th></tr>"
else
    echo "Percent of image with brightest greyscale, top $TOPX"
fi
for P in `cat "$LOG" | cut -d " " -f 8 | sort -n -r | head -n $TOPX`; do
    LINE=`cat "$LOG" | cut -d " " -f 1,8,9 | grep " $P (" | cut -d " " -f 1,3 | head -n 1`
    if [ "html" == "$TYPE" ]; then
        C=`echo "$LINE" | cut -d " " -f 2`
        I=`echo "$LINE" | cut -d " " -f 1`
        REF=${I##*/}
        REF="${REF%.*}"
        LINK="$WEBROOT${I%.*}.html"

        echo "<tr><td>${P}%</td> <td>$C</td> <td><a href=\"$LINK\">$REF</a></td></td></tr>"
    else
        echo "${P}% `echo "$LINE" | cut -d " " -f 2` `echo "$LINE" | cut -d " " -f 1`"
    fi
done
if [ "html" == "$TYPE" ]; then
    echo "</table>"
fi

if [ "html" == "$TYPE" ]; then
    echo "</body>"
    echo "</html>"
fi
