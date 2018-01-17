#!/bin/sh
# Build go-ethereum iOS framework if it does not exist or cleans if
# action argument passed.

if [ $# -eq 0 ]
then
  if [ ! -e "build/bin/Geth.framework" ]; then
    /usr/bin/make ios
  fi
elif [ $1 == "clean" ]
then
  /usr/bin/make clean
fi
