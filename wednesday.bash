#!/bin/bash
#Example bash script for running process script on wed, to send to branches for each system

cd /home/stompro/projects/Paging\ List

/home/stompro/projects/Paging\ List/process-list.pl \
-s SYSTEM1 < \
/home/stompro/projects/Paging\ List/`date +%m%d-%Y`-All-messed-up-holds.data

/home/stompro/projects/Paging\ List/process-list.pl \
-s SYSTEM2 < \
/home/stompro/projects/Paging\ List/`date +%m%d-%Y`-All-messed-up-holds.data
