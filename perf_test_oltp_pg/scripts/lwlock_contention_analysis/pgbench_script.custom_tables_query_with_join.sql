\setrandom val 1 10000
SELECT a.key, a.val, b.val FROM pgbench_child a JOIN pgbench_parent b USING (key) WHERE val = :val;
