
create or replace package body k2_metrics as 

procedure get_metrics is 
    b dataset%rowtype;
    v_dataset_key varchar2(128) := 'k2_metrics';
    v_user_id number := saas_auth_pkg.to_user_id(p_user_name=>'k2');
begin

   if arcsql.is_truthy(app_job.disable_all) or not arcsql.is_truthy(app_job.enable_k2_metrics) then 
      return;
   end if;

   if not k2_metric.does_dataset_exist(v_dataset_key) then 
      k2_metric.create_dataset (
         p_dataset_name=>'Installed by K2 to track generic K2 and application metrics',
         p_dataset_key=>v_dataset_key,
         p_user_id=>v_user_id);
      b := k2_metric.get_dataset_row(p_dataset_key=>v_dataset_key);
      b.calc_type := 'rate/m';
      k2_metric.save_dataset_row(b);
   end if;

   insert into metric_in (
     metric_name,
     metric_key,
     dataset_key,
     metric_time,
     value) (
   select
     'example',
     'example_metric_key',
     v_dataset_key,
     current_timestamp,
     0
   from
     dual
   );

   commit;

end;

end;
/
