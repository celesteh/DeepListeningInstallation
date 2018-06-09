#!/bin/bash

. listen.config

sleep_time=30 #max time to fail * 2

#sleep $initial_pause # initial sleep to let things get started

#rm $alive

sleep $sleep_time

while :
    do

        if [ ! -f $alive ]; then
            echo "File not found! - listen.scd has not checked in and must be hung"
            kill $1
            exit 0
        else

            rm $alive
        fi

        sleep $sleep_time

done
