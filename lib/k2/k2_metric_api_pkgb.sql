-- ToDo: FYI - API is out of date at this point and k2 not ready for this api

create or replace package body k2_metric_api as 

procedure update_metric_v1 ( -- | Sends an updated value for a metric using the dataset token to identify the dataset.
   p_dataset_token varchar2,
   p_metric varchar2,
   p_value number) is 
  v_dataset dataset%rowtype;
begin 
   arcsql.debug3('k2_metric_api.update_metric_v1: '||p_dataset_token||' '||p_metric||' '||p_value);
   -- This will only work if the token is still valid
   v_dataset := k2_metric.get_dataset_row(p_dataset_token=>p_dataset_token);
   insert into metric_in (
      dataset_id,
      metric_key,
      metric_name,
      value) values (
      v_dataset.dataset_id,
      p_metric,
      p_metric,
      p_value);
end;

procedure create_dataset_v1 ( -- | Creates a dataset. All options are initialized with default values.
   p_dataset_key varchar2,
   p_dataset_name varchar2,
   p_user_id in number) is 
begin 
   arcsql.debug('create_dataset_v1: '||p_dataset_key||' '||p_dataset_name||' '||p_user_id);
   k2_metric.create_dataset(
      p_dataset_key=>p_dataset_key, 
      p_dataset_name=>p_dataset_name,
      p_user_id=>p_user_id);
end;

end;
/