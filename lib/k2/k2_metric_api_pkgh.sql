
-- uninstall: exec drop_package('k2_metric_api');

create or replace package k2_metric_api as 

   procedure update_metric_v1 (
      p_dataset_token varchar2,
      p_metric varchar2,
      p_value number);

   procedure create_dataset_v1 (
      p_dataset_key varchar2,
      p_dataset_name varchar2,
      p_user_id in number);
   
end;
/