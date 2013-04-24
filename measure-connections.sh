#!/bin/bash -e
d=$(date +%s.%N)
conns=$(netstat -an | grep ESTABLISHED | wc -l)
echo $d,$conns

