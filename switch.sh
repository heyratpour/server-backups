#!/bin/bash

if [ -z "$__DIR__" ]; then
  __DIR__=$(dirname $0)
fi

while getopts ":c:l:" optname
do
  case "$optname" in
    "c")
      configFilename=$OPTARG
      ;;
    "l")
      LOG_FILE=$OPTARG
      ;;
    "?")
      echo "Unknown option $OPTARG"
      ;;
    ":")
      echo "No argument value for option $OPTARG"
      ;;
    *)
    # Should not occur
      echo "Unknown error while processing options"
      ;;
  esac
done

if [ -z "$configFilename" ]; then
  configFilename=$__DIR__/default-config.sh
fi

BK_INC_SWITCH=1