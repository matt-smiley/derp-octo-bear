#!/bin/bash

# WARNING: Tracing system calls can be very resource intensive.  If you see a spike in system time while
# running this script, you have been warned!
# Also, if the postgres processes are making many syscalls, the act of tracing them is likely to change the
# balance of where time is spent.  If you are checking for race conditions or time-dependent interactions among processes,
# like LWLock contention, then stracing may significantly change the conditions of your test.  Consider the possible differences
# in runtime speed between two concurrent processes, one traced, the other not.  Do they need to signal each other, compete for
# semop calls, allocate shared buffers, do I/O, etc.?

TIMESTAMP=$( date '+%Y%m%d_%H%M%S' )
#OUTDIR="/tmp/strace_$TIMESTAMP"
OUTDIR="/db/scratch/strace_$TIMESTAMP"
DURATION=5

echo "$(date '+%Y-%m-%d %H:%M:%S')  Making output directory: $OUTDIR"
sudo -u postgres mkdir -p -m777 $OUTDIR

echo "$(date '+%Y-%m-%d %H:%M:%S')  Capturing semaphore states."
sudo ipcs -s | awk '/postgres/ {print $2}' | xargs -r -I SEMID sudo -u postgres ipcs -s -i SEMID > $OUTDIR/semid_status.start.$( date '+%Y%m%d_%H%M%S' ).out

echo "$(date '+%Y-%m-%d %H:%M:%S')  Starting straces for all postgres session PIDs." | tee -a $OUTDIR/capture.log
echo "Note: A few processes may fail to attach with a message like: attach: ptrace(PTRACE_ATTACH, ...): Operation not permitted" | tee -a $OUTDIR/capture.log
STRACE_PIDS=""
for PID in $( ps -u postgres -o pid,args | awk '/postgres: .*(local|\([0-9]*\))/ {print $1}' )
do
  sudo -u postgres strace -T -tt -p $PID -o $OUTDIR/strace.postgres.$PID &
  STRACE_PIDS="$STRACE_PIDS $!"
done >> $OUTDIR/capture.log 2>&1
echo

echo "$(date '+%Y-%m-%d %H:%M:%S')  Waiting $DURATION seconds." | tee -a $OUTDIR/capture.log
sleep $DURATION

echo "$(date '+%Y-%m-%d %H:%M:%S')  Killing all strace processes owned by postgres." | tee -a $OUTDIR/capture.log
echo "Note: If any processes failed to attach or were killed or exited since attaching, kill will report those PIDs.  Other PIDs will still be signalled." | tee -a $OUTDIR/capture.log
sudo kill $STRACE_PIDS | tee -a $OUTDIR/capture.log 2>&1 | perl -pe 's/Process \d+ detached.*//m'

echo "$(date '+%Y-%m-%d %H:%M:%S')  Waiting for children to exit." | tee -a $OUTDIR/capture.log
echo "Note: If any child processes (straces) failed to be killed, we (the parent) will hang here.  If we hang here, investigate state of children." | tee -a $OUTDIR/capture.log
wait

echo "$(date '+%Y-%m-%d %H:%M:%S')  Capturing semaphore states."
sudo ipcs -s | awk '/postgres/ {print $2}' | xargs -r -I SEMID sudo -u postgres ipcs -s -i SEMID > $OUTDIR/semid_status.end.$( date '+%Y%m%d_%H%M%S' ).out

echo "$(date '+%Y-%m-%d %H:%M:%S')  Done." | tee -a $OUTDIR/capture.log
