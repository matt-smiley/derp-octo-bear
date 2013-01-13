-- These tables use an exponential distribution of values to induce ANALYZE to save histograms.
-- The default pgbench tables have uniform distributions of values on their join keys, so they
-- lack histograms.  We need histograms to reach the code path we are trying to exercise
-- ("scalarineqsel" from "mergejoinscansel" in selfuncs.c).
drop table if exists pgbench_child ;
drop table if exists pgbench_parent ;
create table pgbench_child as select ( i^1.5 / current_setting('default_statistics_target')::int^1.5 )::int as val from generate_series(1, 10000) s(i) ;
create table pgbench_parent as select distinct val from pgbench_child ;
create index idx_pgbench_child_val_fkey on pgbench_child ( val ) ;
create index unq_pgbench_parent_val on pgbench_parent ( val ) ;
analyze pgbench_child ;
analyze pgbench_parent ;
-- Check that the histograms are not empty.
select tablename, attname, array_length(histogram_bounds, 1) from pg_stats where tablename in ('pgbench_child', 'pgbench_parent') and attname in ('val') order by tablename ;
