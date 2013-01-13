\setrandom val 1 1000
SELECT a.val, b.val FROM pgbench_child a JOIN pgbench_parent b USING (val) WHERE val = :val;
