set linesize 200
set pagesize 1000
col log_entry_id format 999999999
col log_text format a100
col log_type format a10


select log_entry_id, log_text, log_type from arcsql_log where log_type in ('pass', 'fail', 'error') order by 1 desc;


col log_type format a10
col log_message format a100

select count(*) tests,
       log_type
 from arcsql_log
group
   by log_type;