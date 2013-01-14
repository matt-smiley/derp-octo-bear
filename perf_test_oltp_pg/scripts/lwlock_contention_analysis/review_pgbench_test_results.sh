#!/bin/bash

function USAGE () { echo "Usage: $0 [results_dir]"; }

if [ $# -ne 1 ] ; then
    USAGE
    exit 1
fi

cd "$1"

echo "Command-line:"
echo "----------------------------------------------"
cat command.out
echo "----------------------------------------------"

echo ; echo
echo "PgBench output:"
echo "----------------------------------------------"
cat pgbench.out
echo "----------------------------------------------"

echo ; echo
echo "Process lists: Count postgres sessions by time slice and command-type:"
echo "----------------------------------------------"
for f in ps.*.out
do
  echo -n "$f:  "
  cat $f | grep 'postgres:.*toy_db' | perl -e 'while (<>) {chomp; s/.* (\S+).*/$1/; $cnt{$_}++; $cnt{" TOTAL"}++;}; foreach $cmd (sort keys %cnt) {printf "%10s = %3d  ", $cmd, $cnt{$cmd}}; print "\n"'
done
echo "----------------------------------------------"

echo ; echo
echo "SAR: CPU usage"
echo "----------------------------------------------"
sar -u -f sarfile
echo "----------------------------------------------"

echo ; echo
echo "SAR: Disk usage"
echo "----------------------------------------------"
# The /db mountpoint is an LVM volume on dm-2, a multipath roundrobin over dev8-16 and dev8-32.
sar -d -f sarfile | egrep 'DEV|dev253-2'
echo "----------------------------------------------"

echo ; echo
echo "Top: First 5 iterations of top, limited to top 10 CPU consumers"
echo "----------------------------------------------"
grep -A17 -m5 '^top' top.out 
echo "----------------------------------------------"

echo ; echo
echo "Postgres log: First and last lines of the logfile during this run"
echo "----------------------------------------------"
echo -n "Number of log lines: " ; wc -l pglogfile
echo "First and last timestamped log line:" ; grep -m1 '^<' pglogfile ; tac pglogfile | grep -m1 '^<'
echo "----------------------------------------------"

echo ; echo
echo "Postgres log: End-of-session LWLock tallies"
echo "----------------------------------------------"
echo -n "Total number of lwlock log entries: " ; cat pglogfile | grep ' lwlock ' | wc -l
echo
echo "Sum lwlock counters (for all PIDs and lock ids) by lock mode:"
cat pglogfile | grep ' lwlock ' | perl -e 'while (<>) { @val = split /[ :]+/; $key = "TOTAL"; $agg{$key}{sh} += $val[5]; $agg{$key}{ex} += $val[7]; $agg{$key}{blk} += $val[9]; $agg{$key}{spin} += $val[11]; }; foreach $key (sort {length($a)<=>length($b) || $a cmp $b} keys %agg) { printf "%-20s: %10d sh, %10d ex, %10d blk, %10d spindelay\n", $key, $agg{$key}{sh}, $agg{$key}{ex}, $agg{$key}{blk}, $agg{$key}{spin}; }'
echo
echo "Sum lwlock counters (for all lock ids) by PID:"
cat pglogfile | grep ' lwlock ' | perl -e 'while (<>) { @val = split /[ :]+/; $key = "$val[0] $val[1]"; $agg{$key}{sh} += $val[5]; $agg{$key}{ex} += $val[7]; $agg{$key}{blk} += $val[9]; $agg{$key}{spin} += $val[11]; }; foreach $key (sort {length($a)<=>length($b) || $a cmp $b} keys %agg) { printf "%-20s: %10d sh, %10d ex, %10d blk, %10d spindelay\n", $key, $agg{$key}{sh}, $agg{$key}{ex}, $agg{$key}{blk}, $agg{$key}{spin}; }'
echo
echo "Sum lwlock counters (for all PIDs) by lock id, filtered to top 30 by share-lwlock counter:"
cat pglogfile | grep ' lwlock ' | perl -e 'while (<>) { @val = split /[ :]+/; $key = "$val[2] $val[3]"; $agg{$key}{sh} += $val[5]; $agg{$key}{ex} += $val[7]; $agg{$key}{blk} += $val[9]; $agg{$key}{spin} += $val[11]; }; foreach $key (sort {length($a)<=>length($b) || $a cmp $b} keys %agg) { printf "%-20s: %10d sh, %10d ex, %10d blk, %10d spindelay\n", $key, $agg{$key}{sh}, $agg{$key}{ex}, $agg{$key}{blk}, $agg{$key}{spin}; }' | sort -rn -k4 | head -n30 | sort -n -k2
echo
echo "Sum lwlock counters (for all PIDs) by lock id, filtered to top 30 by exclusive-lwlock counter:"
cat pglogfile | grep ' lwlock ' | perl -e 'while (<>) { @val = split /[ :]+/; $key = "$val[2] $val[3]"; $agg{$key}{sh} += $val[5]; $agg{$key}{ex} += $val[7]; $agg{$key}{blk} += $val[9]; $agg{$key}{spin} += $val[11]; }; foreach $key (sort {length($a)<=>length($b) || $a cmp $b} keys %agg) { printf "%-20s: %10d sh, %10d ex, %10d blk, %10d spindelay\n", $key, $agg{$key}{sh}, $agg{$key}{ex}, $agg{$key}{blk}, $agg{$key}{spin}; }' | sort -rn -k6 | head -n30 | sort -n -k2
echo "----------------------------------------------"

echo ; echo
echo "Postgres log: s_lock log entries for every spin"
echo "----------------------------------------------"
echo -n "Total number of 's_lock spin delay' log entries: " ; cat pglogfile | grep -c 's_lock: spin delay from file'
echo
echo "Tally by caller and delay counter:"
cat pglogfile | grep 's_lock: spin delay from file' | perl -pe 's|.*?(s_lock:.*), pointer.*|$1|' | sort | uniq -c
echo "----------------------------------------------"

echo ; echo
echo "Stack traces: "
echo "----------------------------------------------"
NUM_STACKS=$( cat stack_traces.* | grep -c '#0' )
echo "Number of stacks captured: $NUM_STACKS"
for FUNCTION_NAME in semop PGSemaphoreLock LWLockAcquire BufferAlloc ReadBuffer_common ReadBufferExtended index_getnext get_actual_variable_range ineq_histogram_selectivity scalarineqsel mergejoinscansel cached_scansel cost_mergejoin create_mergejoin_path sort_inner_and_outer add_paths_to_joinrel make_join_rel make_rels_by_clause_joins join_search_one_level standard_join_search query_planner grouping_planner subquery_planner standard_planner pg_plan_query pg_plan_queries exec_bind_message PostgresMain
do
  FUNCTION_COUNT=$( cat stack_traces.* | grep -c "^#.* $FUNCTION_NAME " )
  echo "Number of stack frames calling function: $FUNCTION_COUNT $FUNCTION_NAME"
done
echo
RARE_FRAME_PCT_OF_STACKS=5  # Interesting frames must occur in > x % of stacks.
RARE_FRAME_THRESHOLD=$(( $RARE_FRAME_PCT_OF_STACKS * $NUM_STACKS / 100 ))  # Using integer division to alway truncate fractions.
echo "Aggregate stacks by function, source line number, and frame number."
echo "For brevity, omitting rare stack frames occurring in <= $RARE_FRAME_THRESHOLD stacks ($RARE_FRAME_PCT_OF_STACKS%):"
cat stack_traces.* | ../stack_trace_filter.simplify_frames.pl | ../stack_trace_filter.regexp_match_on_whole_stack.pl 'Frame 0' | sort -n -k2 | uniq -c | awk "\$1 >= $RARE_FRAME_THRESHOLD"
echo "----------------------------------------------"
