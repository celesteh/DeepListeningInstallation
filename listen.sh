#!/bin/bash

port=57110

#are we on a raspberry pi
if [ -f /etc/rpi-issue ]
    then
        raspberry=1
       # do pi specific stuff
       # we need these two lines in order to make sound
       export SC_JACK_DEFAULT_INPUTS="system"
       export SC_JACK_DEFAULT_OUTPUTS="system"

    else
        raspberry=0
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac OSX
    sclang=nil
  else
    sclang=sclang
fi

unclutter -idle 0.01 -root &

cd /home/celesteh/Documents/Installations/DeepListeningInstallation

while :
    do
        ## Put your helper scripts here
        ## Ex:
        # python installation_helper.py & 
        # helper=$! #keep the helper's PID

	./jack_script.sh &

	sleep 5


        ## Start your SuperCollider code

                $sclang listen.scd listen.config $port&
        pid=$!



        ## Now stop everything


                ./keepAlive_listen.sh $pid &
        alive_pid=$!

        wait $pid
        kill $alive_pid

        killall scsynth

        ## Kill your helper scripts
        ## Ex:
        # kill $helper || kill -9 $helper
        ## $helper is the PID we kept above


        if [ "$OSTYPE" == "linux-gnu" ] || [ "$OSTYPE" == "freebsd"* ] || [ $raspberry -eq 1 ]
            then
                killall jackd
                sleep 5 #pause longer for jack
        fi

        sleep 5
        port=$((port+1))
done
