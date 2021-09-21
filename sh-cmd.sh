#!/bin/sh

# @author: hustcer
# @create: 2021/09/12 @ Mac OS X
# @desc  : Set up bash command environment

echo;
echo '------------------------------------------------------------------------------------'
echo "I {{LOVE}} curly braces!"
echo
echo "Current Arg #0: $0"
echo "Current Arg #1: $1"
echo "Current Arg1: $arg1"
echo "JUST_DIR: $JUST_DIR"
echo "JUST_FILE: $JUST_FILE"
# To override CURRENT_TAG use `t CURRENT_TAG=v0.0.1.x sh-cmd abc`
# or use `t --set CURRENT_TAG v0.0.1.x sh-cmd abc`
echo "Current Tag: $CURRENT_TAG"
echo "PREV_MALL_TAG: $PREV_MALL_TAG"
CURRENT_PROJECT=`basename "$INVOCATION_DIRECTORY"`
echo "CURRENT_PROJECT: $CURRENT_PROJECT"
echo "Env Mall Tag: $ENV_MALL_TAG"
echo "CMD_ENV_VAR: $CMD_ENV_VAR"
echo "HEAD_ENV_VAR: $HEAD_ENV_VAR"
echo "CMD_ENV_ASSIGNMENT: $CMD_ENV_ASSIGNMENT"
echo "INVOCATION_DIRECTORY: $INVOCATION_DIRECTORY"
echo '------------------------------------------------------------------------------------'
echo;
