create or replace view resource_limits as (
select * from (
select
   resource_name,
   current_utilization,
   max_utilization,
   trim(limit_value) limit_value,
   max_pct max_percent,
   cur_pct cur_percent
 from (
select resource_name||'('||inst_id||')' resource_name,
       current_utilization,
       max_utilization,
       limit_value,
       to_number(decode(rtrim(ltrim(limit_value)), 'UNLIMITED', 0, decode(rtrim(ltrim(limit_value)), '0', 0, round(max_utilization/limit_value*100)))) max_pct,
       to_number(decode(rtrim(ltrim(limit_value)), 'UNLIMITED', 0, decode(rtrim(ltrim(limit_value)), '0', 0, round(current_utilization/limit_value*100)))) cur_pct
  from gv$resource_limit
 where resource_name not like '%gcs%')
));