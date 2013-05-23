#!/bin/bash

if [ -z "$__DIR__" ]; then
  __DIR__=$(dirname $0)
fi

# Include switch controller
source $__DIR__/switch.sh

# Including config file
source $configFilename

SSH_PASS_IS_SET=1
if [ -z "$SCP_PASS" ]; then
    SSH_PASS_IS_SET=0
fi

source $__DIR__/function.sh

BK_INC_HEADER=1