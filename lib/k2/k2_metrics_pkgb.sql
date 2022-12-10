
create or replace package body k2_metrics as 

procedure get_metrics is 
    b stat_bucket%rowtype;
    v_bucket_key varchar2(100) := 'k2_metrics';
    v_user_id number := saas_auth_pkg.to_user_id(p_user_name=>'k2');
begin

   if is_truthy(app_job.disable_all) or not is_truthy(app_job.enable_k2_metrics)) then 
      return;
   end if;

   if not k2_stat.does_bucket_exist(v_bucket_key) then 
      k2_stat.create_bucket(
         p_bucket_name=>'K2 Metrics',
         p_bucket_key=>v_bucket_key,
         p_user_id=>v_user_id));
      b := k2_stat.get_bucket_row(p_bucket_key=>v_bucket_key);
      b.calc_type := 'rate/m';
      k2_stat.save_bucket(b);
   end if;

   insert into stat_in (
     stat_name,
     bucket_key,
     stat_time,
     received_val) (
   select
     'example',
     v_bucket_key,
     current_timestamp,
     0
   from
     dual
   );

   commit;

end;

end;
/
