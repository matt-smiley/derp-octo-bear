#!/bin/bash

EXECUTABLE="$1"

if [ $# -ne 1 ] ; then
    echo "Usage: $0 [script_to_run]"
    exit 1
fi

if [ ! -e "$EXECUTABLE" ] ; then
    echo "ERROR: Cannot find executable: $EXECUTABLE"
    exit 2
fi

if [ ! -x "$EXECUTABLE" ] ; then
    echo "ERROR: Given program is not executable: $EXECUTABLE"
    exit 3
fi

PROGNAME=$( basename $1 )
OUTDIR="/db/archived_logs/$( basename "$EXECUTABLE" )/$( date +%Y%m%d )"
OUTFILE="$OUTDIR/$(date +%Y%m%d_%H%M%S).out"

mkdir -p $OUTDIR
if [ $? -ne 0 ] ; then
    echo "ERROR: Failed to mkdir -p $OUTDIR."
    exit 4
fi

$EXECUTABLE > $OUTFILE 2>&1
if [ $? -ne 0 ] ; then
    echo "ERROR: Command failed: $EXECUTABLE"
    echo "See its log output: $OUTFILE"
    exit 5
fi
