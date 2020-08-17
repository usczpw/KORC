#!/bin/bash

#define input file
INPUT_FILE="input_file_regtest1.korc"
#define output directory
OUT_DIR="OUT_TEST"
OUT_FILE='regtest1.txt'

#check that output directory doesn't exist so bash doesn't complain
if [ ! -d "$OUT_DIR" ]; then
    mkdir $OUT_DIR
fi

#run KORC with input file outputting in desired directory
echo Running KORC with input file $INPUT_FILE and outputting to $OUT_DIR.

#assumes binary directory ../KORC/build/bin was added to path
xkorc $INPUT_FILE $OUT_DIR/ >& $OUT_DIR/$OUT_FILE &

# pause before reading output file
sleep .25

#print last line, which should say "KORC ran successfully!"
test=$( tail -1 $OUT_DIR/$OUT_FILE )
echo $test

