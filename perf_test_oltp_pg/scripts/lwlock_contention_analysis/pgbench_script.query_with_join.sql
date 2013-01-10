\set naccounts 100000 * :scale
\setrandom aid 1 :naccounts
SELECT a.abalance, b.bbalance FROM pgbench_accounts a JOIN pgbench_branches b USING (bid) WHERE aid = :aid;
