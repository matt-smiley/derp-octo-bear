#!/bin/bash

# For reference, the pgbench args are:
#   -c10           Use 10 concurrent clients.  Must be a multiple of pgbench threads (-j).
#   -j10           Use 10 pgbench threads (jobs) to issue client transactions.
#   -M extended    Use the "extended" protocol but without named prepared statements.  Default is "simple" protocol.
#   -S             Transactions are read-only (just the SELECT statement from the default transaction script).
#   -r             Report the average per-statement latency from client's perspective.
#   -T180          Run test for 180 seconds (3 minutes).
#   -p9000         Postgres listener port.

if [ $# -ne 3 ] ; then
    echo "Usage: $0 [concurrent client sessions] [pgbench threads] [duration seconds]"
    echo "Example:"
    echo "  $0 300 10 180"
    echo "Will run with 300 client sessions managed by 10 actual pgbench threads running for 180 seconds (3 minutes)."
    exit 1
fi

PGBENCH_ARGS="-M extended -S -r -c $1 -j $2 -T $3"
PG_CONSTR="-p 9000 toy_db"

RUNID=$( date +%Y%m%d_%H%M%S )
OUTDIR="$( dirname $0 )/results.$RUNID"
mkdir $OUTDIR

echo "$(date '+%Y-%m-%d %H:%M:%S')  Run ID: $RUNID"
echo "$(date '+%Y-%m-%d %H:%M:%S')  Run output dir: $OUTDIR"

echo "$(date '+%Y-%m-%d %H:%M:%S')  Rotating Pg log file."
echo "select pg_rotate_logfile()" | psql -AXqt $PG_CONSTR

echo

PGLOGFILE=$( echo "select current_setting('data_directory') || '/' || current_setting('log_directory') || '/' || filename from pg_ls_dir( current_setting('data_directory') || '/' || current_setting('log_directory') ) dir(filename) order by 1 desc limit 1" | psql -AXqt $PG_CONSTR )
echo "$(date '+%Y-%m-%d %H:%M:%S')  Current Pg log file: $PGLOGFILE"
ln -s $PGLOGFILE $OUTDIR/pglogfile

echo "$(date '+%Y-%m-%d %H:%M:%S')  Capturing sar data frequently."
sar -o $OUTDIR/sarfile 5 > /dev/null 2>&1 &
SAR_PID=$!

# Note: "top" truncates command line length too short to be helpful for postgres processes.  Capture "ps" too to compensate.
echo "$(date '+%Y-%m-%d %H:%M:%S')  Capturing top frequently."
top -b -d5 > $OUTDIR/top.out 2>&1 &
TOP_PID=$!

echo "$(date '+%Y-%m-%d %H:%M:%S')  Capturing ps frequently."
bash -c "while (true) ; do ps -e -o pid,ppid,pcpu,pmem,vsz,rss,s,user,policy,cputime,lstart,args > $OUTDIR/ps.\$(date +%Y%m%d_%H%M%S).out ; sleep 5 ; done" &
PS_PID=$!

PGBENCH_CMD="pgbench $PGBENCH_ARGS $PG_CONSTR"
echo "$(date '+%Y-%m-%d %H:%M:%S')  Running pgbench with following options:"
echo "$(date '+%Y-%m-%d %H:%M:%S')    $PGBENCH_CMD"
PGBENCH_LOG="$OUTDIR/pgbench.out"
echo "$(date '+%Y-%m-%d %H:%M:%S')  Pgbench output redirected to: $PGBENCH_LOG"
$PGBENCH_CMD > $PGBENCH_LOG 2>&1 &
PGBENCH_PID="$!"
wait $PGBENCH_PID

echo
echo "$(date '+%Y-%m-%d %H:%M:%S')  Finished running pgbench."

echo "$(date '+%Y-%m-%d %H:%M:%S')  Killing sar capture."
kill $SAR_PID

echo "$(date '+%Y-%m-%d %H:%M:%S')  Killing top capture."
kill $TOP_PID

echo "$(date '+%Y-%m-%d %H:%M:%S')  Killing ps capture."
kill $PS_PID

echo "$(date '+%Y-%m-%d %H:%M:%S')  Waiting for any remaining child processes."
wait

echo "$(date '+%Y-%m-%d %H:%M:%S')  Done!  Review the results in the output dir:"
echo "$OUTDIR"
