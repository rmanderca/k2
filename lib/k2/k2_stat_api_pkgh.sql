
-- uninstall: exec drop_package('k2_stat_api');

create or replace package k2_stat_api as 

   procedure update_stat_v1 (
      p_bucket_token varchar2,
      p_stat varchar2,
      p_value number);

   procedure create_bucket_v1 (
      p_bucket_key varchar2,
      p_bucket_name varchar2,
      p_user_id in number);
   
end;
/