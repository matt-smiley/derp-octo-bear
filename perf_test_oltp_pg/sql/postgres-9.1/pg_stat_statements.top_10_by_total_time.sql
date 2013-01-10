select
  r.rolname,
  d.datname,
  s.calls,
  round(s.total_time::numeric, 3) as total_time_s,
  case when s.calls > 0 then round(s.total_time::numeric * 1000 / s.calls, 1) end as ms_per_call,
  s.rows,
  substr(s.query, 1, 60) as query_substr
from
  pg_stat_statements s
  left join pg_catalog.pg_roles r on s.userid = r.oid
  left join pg_catalog.pg_database d on s.dbid = d.oid
order by total_time_s desc
limit 10
;
