
exec drop_package('k2_stat');
exec drop_package('k2_stat_api');

-- uninstall: exec drop_package('k2_metric');
create or replace package k2_metric as 

   g_dataset dataset%rowtype;

   function to_dataset_id (
      p_dataset_key in varchar2) return number;

   procedure create_dataset ( 
      p_dataset_name in varchar2,
      p_user_id in number default null,
      p_dataset_key in varchar2 default null,
      p_dataset_type in varchar2 default null,
      p_calc_type in varchar2 default 'none',
      p_allow_negative_values in number default 1,
      p_metric_detail_hours in number default 0,
      p_auto_process in number default 1,
      p_dataset_alt_id in number default null);

   procedure save_dataset_row (
      p_dataset in dataset%rowtype);

   function does_dataset_exist (
      p_dataset_key in varchar2) return boolean;

   function get_dataset_row ( 
      p_dataset_token in number) return dataset%rowtype;

   function get_dataset_row ( 
      p_dataset_key in varchar2) return dataset%rowtype;

   procedure process_datasets_job;

   procedure process_datasets;

   procedure process_dataset (
      p_dataset_id in number);

   procedure purge_metrics (
      p_dataset_id in number, 
      p_metric_id in varchar2);

   procedure delete_dataset (
      p_dataset_id in number);

   procedure refresh_references ( 
      p_dataset_id in number,
      p_metric_id in varchar2);

   procedure refresh_all_references;
   
   procedure generate_test_data (
      p_dataset_id in number,
      p_metric_count in number default 1,
      p_start_time in timestamp default systimestamp-1,
      p_interval_min in number default 5,
      p_metric_alt_id in number default null);

   procedure insert_metric_in (
      p_dataset_id in number default null,
      p_dataset_key in varchar2 default null,
      p_dataset_token in varchar2 default null,
      p_metric_key in varchar2 default null,
      p_metric_name in varchar2 default null,
      p_metric_description in varchar2 default null,
      p_value in number default 0,
      p_metric_time in timestamp default systimestamp,
      p_metric_alt_id in varchar2 default null,
      p_static_json in varchar2 default null,
      p_dynamic_json in varchar2 default null);

   -- procedure purge_dataset (p_dataset_id varchar2);

end;
/
