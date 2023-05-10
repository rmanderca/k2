

begin
   if 1=2 then
      drop_table('dataset');
      drop_table('metric_interval_date_format');
      drop_table('dataset_avg_target_group');
      drop_table('metric');
      drop_table('metric_property');
      drop_table('metric_in');
      drop_table('metric_work');
      drop_table('metric_work_archive');
      drop_table('metric_detail');
      drop_table('metric_pctiles_ref');
      drop_table('metric_avg_val_ref');
      drop_table('metric_profile');
      drop_table('calc_type');
   end if;
end;
/

begin
   if 1=2 then
      drop_table('dataset');
      drop_table('stat_interval_date_format');
      drop_table('dataset_avg_target_group');
      drop_table('stat');
      drop_table('stat_property');
      drop_table('stat_in');
      drop_table('stat_work');
      drop_table('stat_work_archive');
      drop_table('stat_detail');
      drop_table('stat_pctiles_ref');
      drop_table('stat_avg_val_hist_ref');
      drop_table('stat_profile');
      drop_table('stat_work_calc_type');
      drop_table('stat_bucket');
      drop_table('stat_calc_type');
      drop_table('stat_archive');
      drop_table('stat_percentiles_ref');
      drop_view('v_stat_avg_val_hist_ref');
   end if;
end;
/


exec drop_table('metric_archive');

begin
   drop_table('metric_bucket');
   drop_table('metric_bucket_avg_val_ref_group');
   drop_table('metric_bucket_avg_target_group');
   drop_table('metric_bucket_date_format');
   drop_table('metric_bucket_metric_work_date_format');
end;
/

/*

All data starts in the metric_IN (inbound) table.

metric_IN data gets processed in batch.

*/

-- uninstall: exec drop_table('calc_type');
begin 
   if not does_table_exist('calc_type') then
      execute_sql('
      create table calc_type (
      calc_type varchar2(16))', false);
      execute_sql(q'<insert into calc_type (calc_type) values ('none')>');
      execute_sql(q'<insert into calc_type (calc_type) values ('delta')>');
      execute_sql(q'<insert into calc_type (calc_type) values ('rate/s')>');
      execute_sql(q'<insert into calc_type (calc_type) values ('rate/m')>');
      execute_sql(q'<insert into calc_type (calc_type) values ('rate/h')>');
      execute_sql(q'<insert into calc_type (calc_type) values ('rate/d')>');
   end if;
   add_primary_key('calc_type', 'calc_type');
end;
/

-- uninstall: exec drop_table('metric_interval_date_format');
begin 
   -- The date format controls how much granularity you are maintaining in the metric_work table. 
   -- HH24 - metric work keeps one record per hour and updates it throughout the hour.
   -- DY - metric work keeps one record per day and updates it throughout the day.
   -- MM - metric work keeps one record per month and updates it throughout the month.
   if not does_table_exist('metric_interval_date_format') then
      execute_sql('
      create table metric_interval_date_format (
      metric_interval_date_format varchar2(16))', false);
   end if;
   add_primary_key('metric_interval_date_format', 'metric_interval_date_format');
end;
/

declare
   n number;
begin
   select count(*) into n from metric_interval_date_format where metric_interval_date_format='HH24';
   if n = 0 then
      insert into metric_interval_date_format (metric_interval_date_format) values ('HH24');
   end if;
   select count(*) into n from metric_interval_date_format where metric_interval_date_format='DY';
   if n = 0 then
      insert into metric_interval_date_format (metric_interval_date_format) values ('DY');
   end if;
   select count(*) into n from metric_interval_date_format where metric_interval_date_format='MM';
   if n = 0 then
      insert into metric_interval_date_format (metric_interval_date_format) values ('MM');
   end if;
end;
/

-- uninstall: exec drop_table('dataset_avg_target_group');
begin 
   -- -- Historical avg val for metrics is determined by looking at ALL records, DY records matching the day of week, or HH24 records matching the day of week and hour of day.
   if not does_table_exist('dataset_avg_target_group') then
      execute_sql('
      create table dataset_avg_target_group (
      avg_target_group varchar2(16))', false);
   end if;
   add_primary_key('dataset_avg_target_group', 'avg_target_group');
end;
/

declare 
   n number;
begin
   select count(*) into n from dataset_avg_target_group where avg_target_group='ALL';
   if n = 0 then
      insert into dataset_avg_target_group (avg_target_group) values ('ALL');
   end if;
   select count(*) into n from dataset_avg_target_group where avg_target_group='DY';
   if n = 0 then
      insert into dataset_avg_target_group (avg_target_group) values ('DY');
   end if;
   select count(*) into n from dataset_avg_target_group where avg_target_group='HH24';
   if n = 0 then
      insert into dataset_avg_target_group (avg_target_group) values ('HH24');
   end if;
end;
/

/*
get_new_metrics checks metric_work for new metrics and adds them to metric
This means new metrics can exist for a time in metric_work before we fully ack them.
static_properties_json are the json properties which help make up the unique identify of the metric.
We can use the properties to group/categorize/aggregate metrics.
They can made part of the metric name to ensure uniqueness or they can be passed in another field.
*/

/*
static properties embedded within metric name will get parsed when get_new_metric is called.
Dynamic properties will need to be each time metric_work is processed.
For now we are not going to worry about dynamic properties and only allow static.
*/

/*

Datasets are used to group a set of metrics.

The dataset key must be unique across all datasets.

The user_id is optional, links to a row in the saas_auth table when used.

*/

-- uninstall: exec drop_table('dataset');
begin 
   if not does_table_exist('dataset') then
      execute_sql('
      create table dataset (
      dataset_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      user_id number default null,
      dataset_key varchar2(256) not null, -- When creating a dataset you can provide a unique identity
      dataset_alt_id number default null, -- Alternate numberic id a dev can assign to the dataset
      dataset_type varchar2(256) default null,
      dataset_name varchar2(256) not null, -- Uniqueness not required. Your name for this dataset.
      dataset_description varchar2(512) default null,
      calc_type varchar2(16) default ''none'' not null, -- What kind of calc to perform on data in this dataset.
      metric_detail_hours number default 0, -- How long to keep detailed metric history for in metric_detail.
      archive_history_days number default 90, -- The number of days to store archive rows from metric_work for.
      last_metric_time timestamp, -- Last time this dataset was processed.
      calc_count number default 0, -- Number of times this dataset has been processed.
      metric_interval_date_format varchar2(16) default ''HH24'',
      rolling_percentile_days number default 1 not null, -- Number of days of data detail from metric table to determine values for pctiles.
      avg_val_min_row_count number default 7 not null, -- The number of required rows in the HH24 and DY avg val ref sample set before the data can referenced.
      rolling_avg_window_days number default 30 not null, -- How many days are used when calculating the avg historical value of a metric.
      avg_target_group varchar2(16) default ''HH24'', 
      auto_process number default 1 not null, -- If set to zero it is expected the developer will set up a job to process the dataset.
      recv_val_min_allowed number default 0,
      recv_val_max_allowed number default null,
      created timestamp default systimestamp,
      system varchar2(256) default null,
      subsystem varchar2(256) default null,
      application varchar2(256) default null,
      attribute_1 varchar2(256) default null,
      attribute_2 varchar2(256) default null,
      attribute_3 varchar2(256) default null,
      attribute_4 varchar2(256) default null,
      attribute_5 varchar2(256) default null,
      -- ToDo: Get rid of this.
      collect_meta_data number default 1
      -- ToDo: Change auto process to a truthy column which determins when this data is auto-processed.
      -- ToDo: Add enabled/disabled truthy col to specify when this dataset is process/active.
      )');
   end if;
   add_primary_key('dataset', 'dataset_id');
   if not does_index_exist('dataset_1') then 
      execute_sql('create unique index dataset_1 on dataset (dataset_key)');
   end if;
   if not does_constraint_exist('fk_dataset_calc_type') then 
      execute_sql('alter table dataset add constraint fk_dataset_calc_type foreign key (calc_type) references calc_type (calc_type)');
   end if;
   -- ToDo: Change below to look up tables with fk contstraint
   if not does_constraint_exist('dataset_check_3') then
      execute_sql('alter table dataset add constraint dataset_check_3 check (metric_interval_date_format in (''HH24'', ''DY'', ''MM''))');
   end if;
   if not does_constraint_exist('dataset_check_4') then
      execute_sql('alter table dataset add constraint dataset_check_4 check (avg_target_group in (''HH24'', ''DY'', ''ALL''))');
   end if;
   if not does_constraint_exist('fk_metric_interval_date_format') then 
      execute_sql('alter table dataset add constraint fk_metric_interval_date_format foreign key (metric_interval_date_format) references metric_interval_date_format (metric_interval_date_format)');
   end if;
   if not does_constraint_exist('fk_dataset_avg_val_hist_group') then 
      execute_sql('alter table dataset add constraint fk_dataset_avg_val_hist_group foreign key (avg_target_group) references dataset_avg_target_group (avg_target_group)');
   end if;
end;
/

create or replace trigger dataset_before_insert_trg 
   before insert on dataset for each row
begin
   if :new.dataset_key is null then 
      :new.dataset_key := sys_guid;
   end if;
   arcsql.assert_str_is_key_str(:new.dataset_key);
end;
/

create or replace trigger dataset_after_insert_trg 
   before insert on dataset for each row
begin
   insert into tokens (
      token_alt_id, 
      token_type,
      token_description,
      user_id) values (
      :new.dataset_id,
      'dataset_token',
      'Initial token automatically generated for the dataset.',
      :new.user_id);
end;
/

create or replace trigger dataset_before_update_trg 
   before insert on dataset for each row
declare
   n number;
begin
   null;
   -- ToDo: Below is harder than it looks, need to check for data in a lot of places before we know if we can change this. Might want to write a function for this or come up with a better way.
   -- ToDo: Might want to make a way to change this. For now throw an error.
   -- if :new.calc_type != :old.calc_type or :new.calc_type is null then
   --    select count(*) into n from metric_work where dataset_id = :new.dataset_id;
   --    if n > 0 then
   --       raise_application_error(-20000, 'Cannot change calc_type once set.');
   --    end if;
   -- end if;
end;
/

-- uninstall: exec drop_table('metric_in');
begin 
   if not does_table_exist('metric_in') then
      execute_sql('create table metric_in (
      -- Table to hold incoming metrics until they are processed
      metric_in_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      -- One of the next two is required but not both
      dataset_token varchar2(256) default null, 
      dataset_key varchar2(256) default null,
      dataset_id number not null, -- Trigger will figure this one out using the token if not provided
      metric_key varchar2(256) not null, -- Basically the long version of the metric name that is unique within the dataset.
      metric_alt_id number default null, -- User can pass in their own numeric identifier
      metric_id varchar2(256) not null, -- A trigger will base64 the dataset_id and the metric_key to get a unique id across all metrics
      metric_name varchar2(256) not null, -- Shortest name used to identify the metric. Duplicates allowed within the dataset here.
      metric_description varchar2(256) default null,
      static_json varchar2(256) default null,
      dynamic_json varchar2(256) default null,
      metric_time timestamp default systimestamp, -- UTC time
      value number not null,
      system varchar2(256) default null,
      subsystem varchar2(256) default null,
      hostname varchar2(256) default null,
      application varchar2(256) default null,
      created timestamp default systimestamp)');
   end if;
   add_primary_key('metric_in', 'metric_in_id');
   if not does_index_exist('metric_in_1') then 
      execute_sql('create unique index metric_in_1 on metric_in (metric_id, metric_time)');
   end if;
   if not does_constraint_exist('fk_metric_in_dataset_id') then 
      execute_sql('alter table metric_in add constraint fk_metric_in_dataset_id foreign key (dataset_id) references dataset (dataset_id) on delete cascade');
   end if;
end;
/

-- uninstall: exec drop_table('metric_work');
begin 
   if not does_table_exist('metric_work') then
      execute_sql(q''
      create table metric_work (
      metric_work_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      metric_id varchar2(256) not null,
      metric_key varchar2(256) not null,
      metric_alt_id number default null,
      metric_name varchar2(256) not null,
      metric_description varchar2(512) default null,
      metric_level number default 0,
      dataset_id number not null,
      static_json varchar2(512) default null,
      -- Total # of updates for the current hour.
      row_count number default 0,
      -- The raw value received from the metric_in table
      recv_val number default 0 not null,
      recv_val_total number default 0 not null,
      recv_val_avg number default 0 not null,
      recv_val_avg_ref number default 0 not null,
      recv_val_as_pct_of_avg_ref number default 0 not null,
      recv_val_avg_as_pct_of_avg_ref number default 0 not null,
      rolling_recv_val_avg_as_pct_of_avg_ref varchar2(256) default null,
      delta_val number default 0 not null,
      delta_val_total number default 0 not null,
      delta_val_avg number default 0 not null,
      delta_val_avg_ref number default 0 not null,
      delta_val_as_pct_of_avg_ref number default 0 not null,
      delta_val_avg_as_pct_of_avg_ref number default 0 not null,
      rolling_delta_val_avg_as_pct_of_avg_ref varchar2(256) default null,
      rate_per_sec number default 0 not null,
      rate_per_sec_avg number default 0 not null,
      rate_per_sec_avg_ref number default 0 not null,
      rate_per_sec_as_pct_of_avg_ref number default 0 not null,
      rate_per_sec_avg_as_pct_of_avg_ref number default 0 not null,
      rolling_rate_per_sec_avg_as_pct_of_avg_ref varchar2(256) default null,
      -- Seconds elapsed between the current value and last value.
      elapsed_secs number default 0 not null,
      elapsed_secs_total number default 0 not null,
      -- Over-rides the value set in the dataset table if provided.
      calc_type varchar2(16) default null,
      -- String used to convert the received value when applied to any calculations.
      -- ToDo: Should this initially be inherited from the dataset also?
      calc_eval varchar2(128) default null,
      calc_eval_desc varchar2(128) default null,
      -- Time the metric was sampled.
      metric_time timestamp default systimestamp not null,
      -- The metric_time this record was updated.
      updated timestamp default null,
      pctile0x number default 0 not null,
      pctile10x number default 0 not null,
      pctile20x number default 0 not null,
      pctile30x number default 0 not null,
      pctile40x number default 0 not null,
      pctile50x number default 0 not null,
      pctile60x number default 0 not null,
      pctile70x number default 0 not null,
      pctile80x number default 0 not null,
      pctile90x number default 0 not null,
      pctile100x number default 0 not null,
      pctile_score number default 0 not null,
      -- # of times value is in range compared to the avg_val_ref.
      pct10x number default 0 not null,
      pct20x number default 0 not null,
      pct40x number default 0 not null,
      pct80x number default 0 not null,
      pct100x number default 0 not null,
      pct120x number default 0 not null,
      pct240x number default 0 not null,
      pct480x number default 0 not null,
      pct960x number default 0 not null,
      pct1920x number default 0 not null,
      pct9999x number default 0 not null,
      pct_score number default 0 not null,
      rolling_pct_score varchar2(256) default null,
      rolling_pctile_score varchar2(256) default null,
      created timestamp default systimestamp not null,
      refs_row_count number default 0 not null,
      system varchar2(256) default null,
      subsystem varchar2(256) default null,
      hostname varchar2(256) default null,
      application varchar2(256) default null
      )'');
      execute_sql('
      create unique index metric_work_1 on metric_work (dataset_id, metric_key)');
   end if;
   add_primary_key('metric_work', 'metric_id');
   if not does_constraint_exist('metric_work_fk_dataset_id') then
      execute_sql('alter table metric_work add constraint metric_work_fk_dataset_id foreign key (dataset_id) references dataset (dataset_id) on delete cascade');
   end if;
end;
/

-- uninstall: exec drop_table('metric');
begin 
   if not does_table_exist('metric') then
      execute_sql('
         create table metric (
         metric_id varchar2(256) not null,
         static_json varchar2(256) default null,
         dynamic_json varchar2(256) default null,
         created timestamp default systimestamp
         )');
   end if;
   add_primary_key('metric', 'metric_id');
   if not does_constraint_exist('fk_metric_metric_id') then
      execute_sql('alter table metric add constraint fk_metric_metric_id foreign key (metric_id) references metric_work (metric_id) on delete cascade');
   end if;
end;
/

-- uninstall: exec drop_table('metric_profile');
begin 
   if not does_table_exist('metric_profile') then
      execute_sql('
         create table metric_profile (
         metric_profile_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
         metric_id varchar2(256) not null,
         profile_name varchar2(256) not null,
         created timestamp default systimestamp
         )');
   end if;
   add_primary_key('metric_profile', 'metric_profile_id');
   if not does_constraint_exist('fk_metric_profile_metric_id') then
      execute_sql('alter table metric_profile add constraint fk_metric_profile_metric_id foreign key (metric_id) references metric_work (metric_id) on delete cascade');
   end if;
end;
/

-- uninstall: exec drop_table('metric_property');
begin 
   if not does_table_exist('metric_property') then
      execute_sql('
         create table metric_property (
         metric_property_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
         metric_id varchar2(256) not null,
         property_name varchar2(256),
         -- static or dynamic
         -- static properties do not change and are associated with the identiy of the metric
         -- dynamic properties can change and are not part of the properties that make up the unique identify of the metric
         property_type varchar2(32),
         -- All values will be stored as text. 
         property_value varchar2(256) default null,
         -- Y if a number, N if not.
         is_num varchar2(32) not null,
         created timestamp default systimestamp
         )');
   end if;
   add_primary_key('metric_property', 'metric_property_id');
   if not does_constraint_exist('fk_metric_property_metric_id') then
      execute_sql('alter table metric_property add constraint fk_metric_property_metric_id foreign key (metric_id) references metric_work (metric_id) on delete cascade');
   end if;
end;
/


-- uninstall: exec drop_table('metric_work_archive');
begin 
   if not does_table_exist('metric_work_archive') then 
      execute_sql('
      create table metric_work_archive (
      metric_work_archive_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      metric_id varchar2(256) not null,
      metric_key varchar2(256) not null,
      metric_alt_id number default null,
      metric_name varchar2(256) not null,
      dataset_id number not null,
      recv_val_avg number not null,
      recv_val_avg_ref number not null,
      recv_val_avg_as_pct_of_avg_ref number not null,
      delta_val_avg number not null,
      delta_val_avg_ref number not null,
      delta_val_avg_as_pct_of_avg_ref number not null,
      rate_per_sec_avg number not null,
      rate_per_sec_avg_ref number not null,
      rate_per_sec_avg_as_pct_of_avg_ref number not null,
      row_count number,
      elapsed_secs_total number not null,
      metric_time timestamp not null,
      pctile0x number,
      pctile10x number,
      pctile20x number,
      pctile30x number,
      pctile40x number,
      pctile50x number,
      pctile60x number,
      pctile70x number,
      pctile80x number,
      pctile90x number,
      pctile100x number,
      pctile_score number,
      pct10x number,
      pct20x number,
      pct40x number,
      pct80x number,
      pct100x number,
      pct120x number,
      pct240x number,
      pct480x number,
      pct960x number,
      pct1920x number,
      pct9999x number,
      pct_score number,
      created timestamp default systimestamp
      )', false);
   end if;
   add_primary_key('metric_work_archive', 'metric_work_archive_id');
   if not does_constraint_exist('fk_metric_work_archive_metric_id') then
      execute_sql('alter table metric_work_archive add constraint fk_metric_work_archive_metric_id foreign key (metric_id) references metric_work (metric_id) on delete cascade');
   end if;
   if not does_index_exist('metric_work_archive_1') then 
      execute_sql('create unique index metric_work_archive_1 on metric_work_archive (metric_id, metric_time)');
   end if;
end;
/

-- uninstall: exec drop_table('metric_avg_val_ref');
begin
   if not does_table_exist('metric_avg_val_ref') then 
      execute_sql('
      create table metric_avg_val_ref (
      avg_target_group varchar2(16),
      hist_key varchar2(16),
      metric_id varchar2(256) not null,
      row_count number,
      recv_val_avg number,
      delta_val_avg number,
      rate_per_sec_avg number,
      created timestamp default systimestamp
      )', false);
      execute_sql('alter table metric_avg_val_ref add constraint pk_metric_avg_val_ref primary key (avg_target_group, hist_key, metric_id)');
   end if;
   if not does_constraint_exist('fk_metric_avg_val_ref_metric_id') then
      execute_sql('alter table metric_avg_val_ref add constraint fk_metric_avg_val_ref_metric_id foreign key (metric_id) references metric_work (metric_id) on delete cascade');
   end if;
end;
/

-- uninstall: exec drop_table('metric_pctiles_ref');
begin
   if not does_table_exist('metric_pctiles_ref') then 
      execute_sql('
      create table metric_pctiles_ref (
      metric_pctiles_ref_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      metric_id varchar2(256) not null,
      ref_type varchar2(12) not null,
      -- Can be one of recv, delta, rate
      pctile0 number default 0,
      pctile10 number default 0,
      pctile20 number default 0,
      pctile30 number default 0,
      pctile40 number default 0,
      pctile50 number default 0,
      pctile60 number default 0,
      pctile70 number default 0,
      pctile80 number default 0,
      pctile90 number default 0,
      pctile100 number default 0,
      created timestamp default systimestamp,
      updated timestamp default systimestamp
      )');
   end if;
   add_primary_key('metric_pctiles_ref', 'metric_pctiles_ref_id');
   if not does_constraint_exist('fk_metric_pctiles_ref_metric_id') then
      execute_sql('alter table metric_pctiles_ref add constraint fk_metric_pctiles_ref_metric_id foreign key (metric_id) references metric_work (metric_id) on delete cascade');
   end if;
end;
/

-- uninstall: exec drop_view ('v_metric_avg_val_ref');
create or replace view v_metric_avg_val_ref as 
select 'ALL' avg_target_group,
       'ALL' hist_key,
       a.metric_id,     
       sum(row_count) row_count,
       avg(recv_val_avg) recv_val_avg,
       avg(delta_val_avg) delta_val_avg,
       avg(rate_per_sec_avg) rate_per_sec_avg
  from metric_work_archive a,
       (select dataset_id, rolling_avg_window_days from dataset) b 
 where a.dataset_id=b.dataset_id 
   and a.metric_time >= trunc(a.metric_time)-b.rolling_avg_window_days
 group
    by 'ALL',
       'ALL',
       a.metric_id
union all
select 'HH24',
       to_char(metric_time, 'HH24')||':00',
       a.metric_id,     
       sum(row_count) row_count,
       avg(recv_val_avg) recv_val_avg,
       avg(delta_val_avg) delta_val_avg,
       avg(rate_per_sec_avg) rate_per_sec_avg
  from metric_work_archive a,
       (select dataset_id, rolling_avg_window_days from dataset) b 
 where a.dataset_id=b.dataset_id 
   and a.metric_time >= trunc(a.metric_time)-b.rolling_avg_window_days
 group
    by 'HH24',
       to_char(metric_time, 'HH24')||':00',
       a.metric_id
union all
select 'DY',
       to_char(metric_time, 'DY'),
       a.metric_id,     
       sum(row_count) row_count,
       avg(recv_val_avg) recv_val_avg,
       avg(delta_val_avg) delta_val_avg,
       avg(rate_per_sec_avg) rate_per_sec_avg
  from metric_work_archive a,
       (select dataset_id, rolling_avg_window_days from dataset) b 
 where a.dataset_id=b.dataset_id 
   and a.metric_time >= trunc(a.metric_time)-b.rolling_avg_window_days
 group
    by 'DY',
       to_char(metric_time, 'DY'),
       a.metric_id;

-- uninstall: exec drop_table('metric_detail');
begin 
   if not does_table_exist('metric_detail') then 
      execute_sql('
      create table metric_detail (
      metric_detail_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      metric_id varchar2(256) not null,
      recv_val number,
      delta_val number,
      rate_per_sec number,
      elapsed_secs number,
      metric_time timestamp,
      created timestamp default systimestamp
      )', false);
   end if;
   add_primary_key('metric_detail', 'metric_detail_id');
   if not does_constraint_exist('fk_metric_detail_metric_id') then
      execute_sql('alter table metric_detail add constraint fk_metric_detail_metric_id foreign key (metric_id) references metric_work (metric_id) on delete cascade', false);
   end if;
   if not does_index_exist('metric_detail_1') then
      execute_sql('create unique index metric_detail_1 on metric_detail (metric_id, metric_time)', false);
   end if;
end;
/

exec drop_view('metric_work_v');
exec drop_view('metric_work_union_v');
