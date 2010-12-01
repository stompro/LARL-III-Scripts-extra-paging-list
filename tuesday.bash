#!/bin/bash
#Example bash script for running the extra paging lists, this is for running on tuesdays. To send
# Summaries to certain staff before the lists get sent to branches.
cd /home/stompro/projects/Paging\ List

/home/stompro/projects/Paging\ List/process-list.pl \
-s sharon < \
/home/stompro/projects/Paging\ List/`date +%m%d-%Y`-All-messed-up-holds.data

/home/stompro/projects/Paging\ List/process-list.pl \
-s helen < \
/home/stompro/projects/Paging\ List/`date +%m%d-%Y`-All-messed-up-holds.data
