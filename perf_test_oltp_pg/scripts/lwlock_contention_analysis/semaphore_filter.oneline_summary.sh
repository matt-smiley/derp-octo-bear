#!/bin/bash
awk '/^[0-9]/ && ( $3 > 0 || $4 > 0 ) { WAITERS++; NCOUNT+=$3; ZCOUNT+=$4 } END { printf "Total waiters: %d  Nonzero waiters: %d  Zero waiters: %d\n", WAITERS, NCOUNT, ZCOUNT; }'
