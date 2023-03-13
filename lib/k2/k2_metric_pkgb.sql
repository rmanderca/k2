create or replace package body k2_metric as 

procedure create_dataset ( -- | Create a dataset to store metrics in.
   p_dataset_name in varchar2,
   p_user_id in number default null,
   p_dataset_key in varchar2 default null,
   p_dataset_type in varchar2 default null,
   p_metric_work_calc_type in varchar2 default 'none',
   p_allow_negative_values in number default 1,
   p_metric_detail_hours in number default 0,
   p_pause_archive_when_zero_days in number default 0,
   p_auto_process in number default 1,
   p_dataset_alt_id in number default null) is
begin
   arcsql.debug('create_dataset: '||p_dataset_key||', '||p_dataset_name||', '||p_user_id);
   insert into dataset (
      dataset_key,
      dataset_type,
      dataset_name,
      metric_work_calc_type,
      allow_negative_values,
      metric_detail_hours,
      pause_archive_when_zero_days,
      user_id,
      auto_process,
      dataset_alt_id) values (
      p_dataset_key,
      p_dataset_type,
      p_dataset_name,
      p_metric_work_calc_type,
      p_allow_negative_values,
      p_metric_detail_hours,
      p_pause_archive_when_zero_days,
      p_user_id,
      p_auto_process,
      p_dataset_alt_id);
exception 
   when others then 
      arcsql.log_err(p_text=>'create_dataset: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

function get_dataset_row ( -- | Return a row from dataset.
   p_dataset_id in number) return dataset%rowtype is 
   r dataset%rowtype;
begin 
   arcsql.debug2('get_dataset_row: '||p_dataset_id);
   select * into r from dataset where dataset_id=p_dataset_id;
   return r;
end;

function get_dataset_row ( -- | Return a row from dataset.
   p_dataset_key in varchar2) return dataset%rowtype is 
   r dataset%rowtype;
begin 
   arcsql.debug2('get_dataset_row: '||p_dataset_key);
   select * into r from dataset where dataset_key=p_dataset_key;
   return r;
end;

function get_dataset_row ( -- | Return a row from dataset.
   p_dataset_token in number) return dataset%rowtype is 
   r dataset%rowtype;
begin 
   -- ToDo: See if there is anywhere else we are logging tokens
   arcsql.debug_secret('get_dataset_row: '||p_dataset_token);
   k2_token.assert_valid_token(p_token=>p_dataset_token);
   -- Uses the token to find the dataset it belongs to
   select * into r from dataset 
    where dataset_id=(select token_alt_id from tokens where token=p_dataset_token);
   return r;
end;

procedure save_dataset_row ( -- | Save a dataset record if dataset rowtype.
   p_dataset in dataset%rowtype) is 
begin 
   update dataset set row=p_dataset where dataset_id=p_dataset.dataset_id;
exception 
   when others then 
      arcsql.log_err(p_text=>'save_dataset_row: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

function does_dataset_exist ( -- | Return true if the given dataset name exists.
   p_dataset_key in varchar2) return boolean is 
   n number;
begin 
   select count(*) into n from dataset where dataset_key=p_dataset_key;
   return n = 1;
end;

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
   p_dynamic_json in varchar2 default null) is 
begin 
   insert into metric_in (
      metric_name,
      metric_key,
      dataset_id,
      dataset_key,
      dataset_token,
      metric_time,
      value,
      metric_alt_id,
      static_json,
      dynamic_json) values (
      p_metric_name,
      p_metric_key,
      p_dataset_id,
      p_dataset_key,
      p_dataset_token,
      p_metric_time,
      p_value,
      p_metric_alt_id,
      p_static_json,
      p_dynamic_json);
end;  
   
procedure refresh_avg_val_hist_ref ( -- | Refresh the references for the metric's average value.
   p_metric_id in varchar2) is 
begin 

   delete 
     from metric_avg_val_hist_ref 
    where metric_id=p_metric_id;

   insert into metric_avg_val_hist_ref (
      avg_val_target_group,
      metric_id,
      hist_key,
      row_count,
      calc_count,
      avg_val) (select 
      avg_val_target_group,
      metric_id,
      hist_key,
      row_count,
      calc_count,
      avg_val 
      from v_metric_avg_val_hist_ref 
     where metric_id=p_metric_id);
exception
   when others then 
      arcsql.log_err(p_text=>'refresh_avg_val_hist_ref: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure insert_metric_detail_bulk ( -- | Writes out metric detail record.
   p_dataset in dataset%rowtype,
   p_metric_time in timestamp) is 
begin
   arcsql.debug2('insert_metric_detail_bulk: '||p_dataset.dataset_key||', '||p_metric_time);
   insert into metric_detail (
      metric_id,
      metric_work_calc_type,
      calc_val,
      pct_of_avg_val_ref,
      avg_val_ref,
      metric_time,
      delta_val,
      value_received,
      elapsed_seconds,
      rate_per_second
      )
   select 
      metric_id,
      metric_work_calc_type,
      calc_val,
      pct_of_avg_val_ref,
      avg_val_ref,
      metric_time,
      delta_val,
      value_received,
      elapsed_seconds,
      rate_per_second
     from metric_work 
    where dataset_id=p_dataset.dataset_id
      and metric_time=p_metric_time
      -- Only store data if a non zero value exists within the pause_detail_when_zero_hours window.
      and (round(arcsql.secs_between_timestamps(metric_time, last_non_zero_val)/60/60, 2) < p_dataset.pause_detail_when_zero_hours
       or p_dataset.rolling_percentile_days > 0
       or p_dataset.pause_detail_when_zero_hours = 0)
      and calc_count > 0;
   arcsql.debug2('Inserted '||sql%rowcount||' rows');
exception 
   when others then 
      arcsql.log_err(p_text=>'insert_metric_detail_bulk: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure refresh_metric_percentiles_ref ( -- | Refreshes the percentiles reference for given dataset and metric.
   p_dataset_id in number,
   p_metric_id in varchar2) is 
begin 
   g_dataset := get_dataset_row(p_dataset_id=>p_dataset_id);
   delete 
     from metric_percentiles_ref 
    where metric_id=p_metric_id;
   insert into metric_percentiles_ref (
      metric_id, 
      pctile0, 
      pctile10, 
      pctile20, 
      pctile30, 
      pctile40, 
      pctile50, 
      pctile60, 
      pctile70, 
      pctile80, 
      pctile90, 
      pctile100) ( 
   select 
      a.metric_id,
      percentile_cont(.0) within group (order by calc_val),
      percentile_cont(.1) within group (order by calc_val),
      percentile_cont(.2) within group (order by calc_val),
      percentile_cont(.3) within group (order by calc_val),
      percentile_cont(.4) within group (order by calc_val),
      percentile_cont(.5) within group (order by calc_val),
      percentile_cont(.6) within group (order by calc_val),
      percentile_cont(.7) within group (order by calc_val),
      percentile_cont(.8) within group (order by calc_val),
      percentile_cont(.9) within group (order by calc_val),
      percentile_cont(1) within group (order by calc_val)
   from metric_detail a
   where a.metric_id=p_metric_id  
     and a.metric_time >= a.metric_time-k2_metric.g_dataset.rolling_percentile_days
   group by
      a.metric_id);
exception
   when others then 
      arcsql.log_err(p_text=>'refresh_metric_percentiles_ref: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure refresh_references ( -- | Refresh references for a metric.
   p_dataset_id in number,
   p_metric_id in varchar2) is 
begin 
   refresh_avg_val_hist_ref (p_metric_id);
   refresh_metric_percentiles_ref (p_dataset_id, p_metric_id);
exception
   when others then
      arcsql.log_err(p_text=>'refresh_references: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure refresh_all_references is -- | Scheduled job runs this to refresh all references periodically.
   cursor all_metrics is 
   -- ToDo: No need to refresh references if data has not been updated in a while
   select metric_id, dataset_id
     from metric_work
    order
       by metric_id, metric_key;
begin 
   if arcsql.is_truthy(app_job.disable_all) or not arcsql.is_truthy(app_job.process_k2_metrics) then 
      return;
   end if;
   arcsql.start_event(p_event_key=>'k2_metric', p_sub_key=>'refresh_all_references', p_name=>'refresh_all_references');
   for x in all_metrics loop 
      purge_metrics (x.dataset_id, x.metric_id);
      refresh_references (x.dataset_id, x.metric_id);
   end loop;
   arcsql.stop_event(p_event_key=>'k2_metric', p_sub_key=>'refresh_all_references', p_name=>'refresh_all_references');
exception
   when others then
      arcsql.log_err(p_text=>'refresh_all_references: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure get_properties_from_new_metrics ( -- | Parse the properties from the metricic_json column for new metrics.
   p_created in timestamp) is 
   cursor c_new_metrics is 
   select static_json, metric_id
    from metric
   where created=p_created;
   j json_object_t;
   keys json_key_list;
   v_property_name varchar2(256);
   v_property_value varchar2(256);
begin 
   -- Example of data: {"instance_id": 1, "statistic#": 653, "class": 1, "type": "oracle"}
   for c in c_new_metrics loop
      begin
         j := json_object_t (c.static_json);
         keys := j.get_keys;
         for ki in 1..keys.count loop
            v_property_name := keys(ki);
            v_property_value := j.get_string(keys(ki));
            insert into metric_property (
               metric_id,
               property_name,
               property_value,
               property_type,
               is_num,
               created) values (
               c.metric_id,
               v_property_name,
               v_property_value,
               'static',
               arcsql.str_is_number_y_or_n(v_property_value),
               p_created);
         end loop;
      exception 
         when others then 
            arcsql.log_err('get_properties_from_new_metrics: metric_id='||c.metric_id);
            arcsql.log_err('get_properties_from_new_metrics: '||dbms_utility.format_error_stack);
      end;
   end loop;
exception
   when others then 
      arcsql.log_err(p_text=>'get_properties_from_new_metrics: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure apply_profile_to_new_metrics (
   p_dataset_id in number,
   p_created_timestamp in timestamp) is 
   v_profile_id number;
begin 
   null;
end;

procedure get_new_metrics_from_the_metric_work_table ( -- | Checks metric_work for new metrics and adds to metric table if any found.
   p_dataset_id in number) is 
   v_created timestamp(0) := systimestamp;
begin 
   arcsql.debug2('get_new_metrics_from_the_metric_work_table: '||p_dataset_id);
   insert into metric s (
      metric_id,
      -- If this is null a trigger will attempt to parse the json from metric_name if embedded there.
      static_json,
      created) (
   select sw.metric_id,
          sw.static_json,
          v_created
     from metric_work sw
    where dataset_id=p_dataset_id 
      and not exists (
      select 'x'
        from metric s
       where dataset_id=p_dataset_id
         and s.metric_id=sw.metric_id));
   -- ToDo: Re-implement later
   -- get_properties_from_new_metrics(v_created);
exception 
   when others then 
      arcsql.log_err(p_text=>'get_new_metrics_from_the_metric_work_table: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure process_dataset_time ( -- | Process the records in metric_in for given dataset and given time.
   p_dataset_id in number, 
   p_metric_time in timestamp) is
   -- Updates metric_work table, then inserts new rows from metric_in.
begin
   arcsql.debug2('process_dataset_time: '||p_dataset_id||', '||to_char(p_metric_time, 'HH24:MI:SS'));
   if g_dataset.dataset_id is null then 
      -- This seems to happen when Oracle free db may be short on resources, it's sort of random.
      arcsql.log_err('process_dataset_time: g_dataset not set, will try again!');
      select * into g_dataset from dataset where dataset_id=p_dataset_id;
      if g_dataset.dataset_id is null then 
         raise_application_error(-20001, 'process_dataset_time: g_dataset not set');
      end if;
   end if;
   -- Update matching rows in metric_work from metric_in.
   update metric_work sw
      set (value_received,
          metric_time,
          -- This is the column which will cause the trigger to fire! This needs to be here.
          updated) = (
   select si.value,
          si.metric_time,
          systimestamp
     from metric_in si 
    where si.metric_time=p_metric_time
      and si.metric_id=sw.metric_id)
    where exists (
   select 'x'
     from metric_in si2
    where si2.metric_id=sw.metric_id 
      and si2.metric_time=p_metric_time);
   arcsql.debug2('Updated '||sql%rowcount||' rows in metric_work');

   -- Insert new records from metric_in into metric_work.
   insert into metric_work a (
      metric_name,
      metric_id,
      metric_key,
      metric_description,
      dataset_id,
      metric_work_calc_type,
      value_received,
      metric_time,
      updated,
      metric_alt_id) (
   select 
      metric_name,
      metric_id,
      metric_key,
      metric_description,
      g_dataset.dataset_id,
      k2_metric.g_dataset.metric_work_calc_type,
      value,
      metric_time,
      systimestamp,
      metric_alt_id
     from metric_in b
    where b.dataset_id=p_dataset_id
      and b.metric_time=p_metric_time
      and not exists (
    select 'x'
      from metric_work c 
     where c.dataset_id=p_dataset_id
       and c.metric_key=b.metric_key 
       and c.dataset_id=p_dataset_id));
   arcsql.debug2('Inserted '||sql%rowcount||' rows into metric_work');

   delete from metric_in 
    where dataset_id=p_dataset_id
      and metric_time=p_metric_time;
   arcsql.debug2('Deleted '||sql%rowcount||' rows from metric_in.');

   update dataset 
      set last_metric_time=p_metric_time, 
          calc_count=calc_count+1
    where dataset_id=p_dataset_id;

exception 
   when others then 
      arcsql.log_err(p_text=>'process_dataset_time: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure process_dataset ( -- | Process records in metric_in for the given dataset name.
   p_dataset_id in number) is 
   cursor metric_times is 
   select distinct metric_time 
     from metric_in 
    where dataset_id=p_dataset_id
    order by 1;
   n number;
begin 
   arcsql.debug2('process_dataset: '||p_dataset_id);
   -- ToDo: Might be cool if we have a interface to track all events easily and couters in k2 as part of k2 metrics
   arcsql.start_event(p_event_key=>'k2_metric', p_sub_key=>'process_dataset', p_name=>p_dataset_id);
   -- Needs to be set here so it is available for triggers which are about to fire.
   g_dataset := get_dataset_row(p_dataset_id=>p_dataset_id);
   for t in metric_times loop 
      process_dataset_time (p_dataset_id=>p_dataset_id, p_metric_time=>t.metric_time);
      -- Re: rolling_percentile_days, detailed data is required if we need to compare percentiles.
      if g_dataset.metric_detail_hours > 0 or g_dataset.rolling_percentile_days > 0 then 
         insert_metric_detail_bulk(p_dataset=>g_dataset, p_metric_time=>t.metric_time);
      end if;
   end loop;
   -- Check metric_work for new metrics and insert into metric table if we find any.
   get_new_metrics_from_the_metric_work_table(p_dataset_id=>p_dataset_id);
   arcsql.stop_event(p_event_key=>'k2_metric', p_sub_key=>'process_dataset', p_name=>p_dataset_id);
exception 
   when others then 
      arcsql.log_err(p_text=>'process_dataset: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure process_datasets_job is -- | Called from scheduled task.
begin 
   if arcsql.is_truthy(app_job.disable_all) or not arcsql.is_truthy(app_job.process_k2_metrics) then 
      return;
   end if;
   process_datasets;
end;

procedure process_datasets is -- | Process all datasets where auto_process is enabled (not zero)
   cursor datasets is 
   select distinct a.dataset_id
     from metric_in a,
          dataset b
    where a.dataset_id=b.dataset_id
      and b.auto_process != 0;
begin
   for b in datasets loop
      process_dataset(p_dataset_id=>b.dataset_id);
   end loop;
   commit;
exception 
   when others then 
      arcsql.log_err(p_text=>'process_datasets: '||dbms_utility.format_error_stack, p_key=>'k2');
      rollback;
      raise;
end;

procedure purge_metrics ( -- | Delete old data from metric_detail and metric_work_archive.
   p_dataset_id in number,
   p_metric_id in varchar2) is 
   max_metric_detail_hours number;
begin 
   arcsql.debug2('purge_metrics: '||p_metric_id);
   g_dataset := get_dataset_row(p_dataset_id=>p_dataset_id);
   -- We may need to keep data to calculate percentiles.
   max_metric_detail_hours := greatest(g_dataset.rolling_percentile_days*24, g_dataset.metric_detail_hours);
   delete from metric_detail
    where metric_id=p_metric_id 
      and metric_time < systimestamp-(max_metric_detail_hours/24);
   delete from metric_work_archive
    where metric_id=p_metric_id 
      and metric_time < systimestamp-k2_metric.g_dataset.archive_history_days;
exception
   when others then
      arcsql.log_err(p_text=>'purge_metrics: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

procedure delete_dataset ( -- | Delete a dataset for the given dataset id.
   p_dataset_id in number) is
begin 
  delete from dataset 
   where dataset_id=p_dataset_id;
exception
   when others then 
      arcsql.log_err(p_text=>'delete_dataset: '||dbms_utility.format_error_stack, p_key=>'k2');
      raise;
end;

function to_dataset_id (
   p_dataset_key in varchar2)
   return number is
   n number;
begin
   select dataset_id into n from dataset where dataset_key=p_dataset_key;
   return n;
end;

procedure generate_test_data (
   -- ToDo: This is wrong, should use token!
   p_dataset_id in number,
   p_metric_count in number default 1,
   p_start_time in timestamp default systimestamp-1,
   p_interval_min in number default 5,
   p_metric_alt_id in number default null) is 
   v_metric_counter number;
   v_current_time timestamp := p_start_time;
   v_value number;
begin
   while v_current_time < systimestamp loop 
      for v_metric_counter in 1..p_metric_count loop
         v_value := round(arcsql.num_random_gauss(p_mean=>85, p_dev=>10, p_min=>0, p_max=>125));
         insert into metric_in (
            metric_name,
            metric_key,
            dataset_id,
            metric_time,
            value,
            metric_alt_id) values (
            'Test metric '||v_metric_counter,
            'test-metric-'||v_metric_counter,
            p_dataset_id,
            v_current_time,
            v_value,
            p_metric_alt_id);
         v_current_time := v_current_time + (p_interval_min/1440);
      end loop;
      k2_metric.process_dataset(p_dataset_id=>p_dataset_id);
   end loop;
end;

end;
/
