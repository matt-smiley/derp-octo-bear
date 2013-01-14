#!/bin/bash

function USAGE ()
{
    cat <<HERE
Usage: $0 'pgbench args'

Note:
This script assumes you have started postgres with the custom build:
/usr/pgsql-9.1-custom-lock-debug/bin/pg_ctl -D /run/shm/toy_db/ start

Examples:
  $0 '-M extended -c 300 -j 10 -T 180 -S -r'
Will run with 300 client sessions managed by 10 actual pgbench threads running for 180 seconds (3 minutes).
Each thread will run only the SELECT (-S) portion of the default transaction script.  When done, pgbench
will show a summary report of average latencies from the client perspective.

  $0 '-M extended -c 9 -j 3 -T 10 -n -r -f pgbench_script.custom_tables_query_with_join.sql'
This is a short 10-second run with a modest number of sessions (9) and client threads (3).
It uses a custom pgbench "transaction script".  Since the custom script also uses tables other than the
standard 4 pgbench tables, suppress the initial vacuuming (-n) of the pgbench_* tables.
For reference when writing a custom script, see:
http://www.postgresql.org/docs/9.1/static/pgbench.html#AEN136638

For reference, the pgbench args are:
  -c N           Use N concurrent client sessions.  Must be a multiple of pgbench threads (-j).
  -j N           Use N pgbench threads (jobs) to issue client transactions.
  -M extended    Use the "extended" protocol but without named prepared statements.  Default is "simple" protocol.  "prepared" uses named statements.
  -f FILENAME    Use transaction script FILENAME instead of the default.
  -S             Transactions are read-only (just the SELECT statement from the default transaction script).
  -r             Report the average per-statement latency from client's perspective.
  -T N           Run test for N seconds.
  -n             Skip the VACUUM on the 4 pgbench tables.  Use this when working with custom tables.
HERE
}

if [ $# -ne 1 ] ; then
    USAGE
    exit 1
fi

PGBENCH_ARGS="$1"
PG_CONSTR="-p 9000 toy_db"

echo "$(date '+%Y-%m-%d %H:%M:%S')  Confirming we can run sudo (used by some capture routines)."
sudo -v
if [ $? -ne 0 ] ; then
    echo "ERROR: Failed the sudo test.  Please either enable sudo or disable the semaphore and stack trace captures."
    exit 1
fi

RUNID=$( date +%Y%m%d_%H%M%S )
TOPDIR="$( dirname $0 )"
OUTDIR="$TOPDIR/results.$RUNID"
cd "$TOPDIR"
mkdir "$OUTDIR"

( for arg in "$0" "$@" ; do echo "'$arg' " ; done ) > $OUTDIR/command.out

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

echo "$(date '+%Y-%m-%d %H:%M:%S')  Capturing semaphore arrays' states frequently."
bash -c "while (true) ; do $TOPDIR/capture_semaphore_array_states.sh > $OUTDIR/semid_states.\$(date +%Y%m%d_%H%M%S).out 2>&1 ; sleep 5 ; done" &
SEMID_PID=$!

echo "$(date '+%Y-%m-%d %H:%M:%S')  Capturing stack traces serially but frequently."
bash -c "while (true) ; do $TOPDIR/capture_stack_traces_from_nonidle_postgres_pids.sh > $OUTDIR/stack_traces.\$(date +%Y%m%d_%H%M%S).out 2>&1 ; sleep 5 ; done" &
STACK_PID=$!

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

echo "$(date '+%Y-%m-%d %H:%M:%S')  Killing semaphore arrays capture."
kill $SEMID_PID

echo "$(date '+%Y-%m-%d %H:%M:%S')  Killing stack trace capture."
kill $STACK_PID

echo "$(date '+%Y-%m-%d %H:%M:%S')  Rotating Pg log file again, to close the book for this run."
echo "select pg_rotate_logfile()" | psql -AXqt $PG_CONSTR

echo "$(date '+%Y-%m-%d %H:%M:%S')  Waiting for any remaining child processes."
wait

echo "$(date '+%Y-%m-%d %H:%M:%S')  Generating results summary: $OUTDIR/results_summary.out"
$TOPDIR/review_pgbench_test_results.sh "$OUTDIR" > $OUTDIR/results_summary.out

echo "$(date '+%Y-%m-%d %H:%M:%S')  Done!  Review the results in the output dir: $OUTDIR"
