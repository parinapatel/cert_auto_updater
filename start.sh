#!/usr/bin/env bash

/home/user/run.sh 2>&1 | au2 log w -i ${AU_LOGGER_STREAM} -s
exit_code=$?
if  [[ $exit_code -eq 0 ]]
then
    echo "SUCCEEDED"
else
   echo "FAILED"
    exit 1     
fi