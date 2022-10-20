
exec drop_package('statzilla_b');
exec drop_constraint('STAT_DEFAILT_FK_BUCKET_ID');

/*

All data starts in the STAT_IN (inbound) table.

STAT_IN data gets processed in batch.

*/

/*
Note: Not using a number for PK here because they can be harder to migrate.
*/

-- uninstall: drop table stat_calc_type cascade constraints purge;
begin 
   if not does_table_exist('stat_calc_type') then
      execute_sql('
      create table stat_calc_type (
      calc_type varchar2(12))', false);
      execute_sql('alter table stat_calc_type add constraint pk_stat_calc_type primary key (calc_type)', false);
      execute_sql('insert into stat_calc_type (calc_type) values (''none'')', false);
      execute_sql('insert into stat_calc_type (calc_type) values (''delta'')', false);
      execute_sql('insert into stat_calc_type (calc_type) values (''rate/s'')', false);
      execute_sql('insert into stat_calc_type (calc_type) values (''rate/m'')', false);
      execute_sql('insert into stat_calc_type (calc_type) values (''rate/h'')', false);
      execute_sql('insert into stat_calc_type (calc_type) values (''rate/d'')', false);
   end if;
end;
/

/*
get_new_stats checks stat_work for new stats and adds them to stat
This means new stats can exist for a time in stat_work before we fully ack them.
static_properties_json are the json properties which help make up the unique identify of the stat.
We can use the properties to group/categorize/aggregate stats.
They can made part of the stat name to ensure uniqueness or they can be passed in another field.
*/

-- uninstall: exec drop_table('stat');
begin 
   if not does_table_exist('stat') then
      execute_sql('
         create table stat (
         stat_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
         -- Must be unique within bucket_id.
         stat_name varchar2(250) not null,
         bucket_id number not null,
         static_json varchar2(250) default null,
         dynamic_json varchar2(250) default null,
         created timestamp(0) with time zone default systimestamp
         )', false);
      execute_sql('alter table stat add constraint pk_stat primary key (stat_id)', false);
      execute_sql('create unique index stat_1 on stat(stat_name, bucket_id)', false);
   end if;
end;
/

/*
Static properties embedded within stat name will get parsed when get_new_stat is called.
Dynamic properties will need to be each time stat_work is processed.
For now we are not going to worry about dynamic properties and only allow static.
*/

-- uninstall: exec drop_table('stat_property');
begin 
   if not does_table_exist('stat_property') then
      execute_sql('
         create table stat_property (
         stat_property_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
         stat_id varchar2(250),
         property_name varchar2(250),
         -- static or dynamic
         -- static properties do not change and are associated with the identiy of the stat
         -- dynamic properties can change and are not part of the properties that make up the unique identify of the stat
         property_type varchar2(50),
         -- All values will be stored as text. 
         property_value varchar2(255) default null,
         -- Y if a number, N if not.
         is_num varchar2(1) not null,
         created timestamp(0) with time zone default systimestamp
         )', false);
      execute_sql('alter table stat_property add constraint pk_stat_property primary key (stat_property_id)', false);
   end if;
end;
/

/*
Buckets will get linked to an account. Not going to be stored here.
*/

-- uninstall: exec drop_table('stat_bucket');
begin 
   if not does_table_exist('stat_bucket') then
      execute_sql('
      create table stat_bucket (
      bucket_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      -- Will be unique within account but not enforced here.
      bucket_name varchar2(250) not null,
      -- What kind of calc to perform on data in this bucket.
      -- ToDo: Need a trigger that handles conversions when this is changed.
      calc_type varchar2(12) default ''none'' not null,
      -- How long to keep detailed stat history for.
      save_stat_hours number default 0,
      -- Stop saving detail data if value have all been 0 for X hours.
      -- ToDo: May want the reverse of this. Stop saving detail if > 0 for X hours. 
      skip_stat_hours number default 0,
      -- The number of days to store archive rows from stat_work for.
      save_archive_days number default 90,
      -- Stop archiving data if values have all been 0 for X hours.
      -- ToDo: See above, may want the reverse of this?
      skip_archive_hours number default 0,
      -- Last time this bucket was calc.
      last_stat_time timestamp(0) with time zone,
      -- Number of times calc has been run on this bucket.
      calc_count number default 0,
      -- If a counter rolls you can see a big negative value. We may want to ignore these.
      ignore_negative varchar2(1) default ''N'' not null,
      -- The date format controls how much granularity you are maintaining in the stat_work table. 
      -- HH24 - Stat work keeps one record per hour and updates it throughout the hour.
      -- DY - Stat work keeps one record per day and updates it throughout the day.
      -- MM - Stat work keeps one record per month and updates it throughout the month.
      date_format varchar2(120) default ''HH24'',
      -- Number of days of data from stat table to determine values for pctiles.
      percentile_calc_days number default 1 not null,
      -- The number of required rows in the HH24 and DY avg val ref sample set before the data can referenced.
      avg_val_required_row_count number default 7 not null,
      -- How many days are used when calculating the avg historical value of a stat.
      avg_val_hist_days number default 30 not null,
      -- Historical avg val for stats is determined by looking at ALL records, DY records matching the day of week, or HH24 records matching the day of week and hour of day.
      -- Must be one of HH24, DY, or ALL.
      avg_val_ref_group varchar2(12) default ''HH24'',
      -- bucket_description varchar2(100),
      created timestamp(0) with time zone default systimestamp
      )', false);

      execute_sql('alter table stat_bucket add constraint pk_stat_bucket primary key (bucket_id)', false);
      execute_sql('alter table stat_bucket add constraint stat_bucket_fk_calc_type foreign key (calc_type) references stat_calc_type (calc_type) on delete cascade', false);
      execute_sql('create unique index stat_bucket_1 on stat_bucket (bucket_name)', false);
      
   end if;
   if not does_constraint_exist('stat_bucket_check_1') then
      execute_sql('alter table stat_bucket add constraint stat_bucket_check_1 check (calc_type in (''none'', ''delta'', ''rate/s'', ''rate/m'', ''rate/d'', ''rate/m''))', false);
   end if;
   if not does_constraint_exist('stat_bucket_check_2') then
      execute_sql('alter table stat_bucket add constraint stat_bucket_check_2 check (ignore_negative in (''Y'', ''N''))', false);
   end if;
   if not does_constraint_exist('stat_bucket_check_3') then
      execute_sql('alter table stat_bucket add constraint stat_bucket_check_3 check (date_format in (''HH24'', ''DY'', ''MM''))', false);
   end if;
   if not does_constraint_exist('stat_bucket_check_4') then
      execute_sql('alter table stat_bucket add constraint stat_bucket_check_4 check (avg_val_ref_group in (''HH24'', ''DY'', ''ALL''))', false);
   end if;
end;
/

/*
Account X and Y may both have buckets called "foo".
We will store the bucket name as 'foo {account: 123}' and 'foo {account: 567}'.
Anytime we act on behalf an account we will need to inject the account.
Bucket are unique with accounts.
*/

-- uninstall: exec drop_table('stat_in');
begin 
   if not does_table_exist('stat_in') then
      execute_sql('create table stat_in (
      stat_in_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      stat_name varchar2(250) not null,
      static_json varchar2(250) default null,
      dynamic_json varchar2(250) default null,
      bucket_name varchar2(250) not null,
      stat_time timestamp(0) with time zone default systimestamp,
      received_val number not null,
      created timestamp(0) with time zone default systimestamp)', false);
      execute_sql('
      alter table stat_in add constraint pk_stat_in primary key (stat_in_id)', false);
   end if;
   if not does_index_exist('stat_in_1') then 
      execute_sql('create unique index stat_in_1 on stat_in (stat_name, bucket_name, stat_time)', false);
   end if;
end;
/

-- uninstall: exec drop_table('stat_archive');
begin 
   if not does_table_exist('stat_archive') then 
      execute_sql('
      create table stat_archive (
      stat_work_id number,
      stat_name varchar2(250) not null,
      stat_level number default 0,
      bucket_id number not null,
      received_val number not null,
      calc_count number default 0,
      calc_type varchar2(12),
      neg_calc_count number default 0,
      zero_calc_count number default 0,
      avg_val number,
      stat_time timestamp(0) with time zone not null,
      last_non_zero_val timestamp(0) with time zone,
      pctile0x number default 0,
      pctile10x number default 0,
      pctile20x number default 0,
      pctile30x number default 0,
      pctile40x number default 0,
      pctile50x number default 0,
      pctile60x number default 0,
      pctile70x number default 0,
      pctile80x number default 0,
      pctile90x number default 0,
      pctile100x number default 0,
      pctile_score number default 0,
      pct10x number default 0,
      pct20x number default 0,
      pct40x number default 0,
      pct80x number default 0,
      pct100x number default 0,
      pct120x number default 0,
      pct240x number default 0,
      pct480x number default 0,
      pct960x number default 0,
      pct1920x number default 0,
      pct9999x number default 0,
      pct_score number default 0,
      avg_val_ref number default 0,
      avg_val_ref_group varchar2(12) default null,
      avg_pct_of_avg_val_ref number default 0,
      created timestamp(0) with time zone default systimestamp
      )', false);
   end if;
   if not does_constraint_exist('stat_archive_fk_bucket_id') then
      execute_sql('alter table stat_archive add constraint stat_archive_fk_bucket_id foreign key (bucket_id) references stat_bucket (bucket_id) on delete cascade', false);
   end if;
   if not does_column_exist('stat_archive', 'avg_pct_of_avg_val_ref') then 
      execute_sql('alter table stat_archive add avg_pct_of_avg_val_ref number default 0', false);
   end if;
   if not does_index_exist('stat_archive_1') then 
      execute_sql('create unique index stat_archive_1 on stat_archive (stat_name, stat_time, bucket_id)', false);
   end if;
   if not is_column_nullable('stat_archive', 'last_non_zero_val') then
      execute_sql('
      alter table stat_archive modify last_non_zero_val timestamp(0) with time zone null', false);
   end if;
   if not does_column_exist('stat_archive', 'pctile_score') then 
      execute_sql('alter table stat_archive add pctile_score number default 0', false);
   end if;
   if not does_column_exist('stat_archive', 'pct_score') then 
      execute_sql('alter table stat_archive add pct_score number default 0', false);
   end if;
   if not does_column_exist('stat_archive', 'neg_calc_count') then 
      execute_sql('alter table stat_archive add neg_calc_count number default 0', false);
   end if;
   if not does_column_exist('stat_archive', 'zero_calc_count') then 
      execute_sql('alter table stat_archive add zero_calc_count number default 0', false);
   end if;
   if not does_column_exist('stat_archive', 'stat_level') then 
      execute_sql('alter table stat_archive add stat_level number default 0', false);
   end if;
end;
/

-- uninstall: drop sequence seq_stat_work_id;
exec create_sequence('seq_stat_work_id');

-- uninstall: exec drop_table('stat_work');
begin 
   if not does_table_exist('stat_work') then
      execute_sql('
      create table stat_work (
      stat_work_id number default seq_stat_work_id.nextval not null,
      stat_name varchar2(250) not null,
      stat_level number default 0,
      bucket_id number not null,
      static_json varchar2(250) default null,
      -- The value taken from the STAT_IN table.
      received_val number not null,
      -- The delta is equal to current value minus last value.
      delta_val number default 0 not null,
      -- Seconds elapsed between the current value and last value.
      elapsed_seconds number default 0 not null,
      -- Rate of delta per second.
      rate_per_second number,
      -- This is mirrored from the bucket, this does not control the calc_type.
      calc_type varchar2(12),
      -- Tracks the # of times the calc_val was negative.
      neg_calc_count number default 0,
      -- Tracks the # of times the calc_val was zero.
      zero_calc_count number default 0,
      -- The value we care about after processing it per "calc_type".
      calc_val number default 0,
      -- Average of calc_val for the current hour. This needs to be null to begin
      -- as the update trigger references this field in one case to check for null.
      avg_val number default 0 not null,
      -- Current value as a % of one of the historical values.
      pct_of_avg_val_ref number default 0 not null,
      -- Current avg value for pct_of_avg_val_ref.
      avg_pct_of_avg_val_ref number default 0 not null,
      -- Total # of updates for the current hour.
      calc_count number default 0,
      -- Time the stat was sampled.
      stat_time timestamp(0) with time zone,
      -- The stat_time this record was updated.
      updated timestamp(0) with time zone default systimestamp,
      -- Last time a non-zero value was calculated.
      last_non_zero_val timestamp(0) with time zone,
      pctile0x number default 0,
      pctile10x number default 0,
      pctile20x number default 0,
      pctile30x number default 0,
      pctile40x number default 0,
      pctile50x number default 0,
      pctile60x number default 0,
      pctile70x number default 0,
      pctile80x number default 0,
      pctile90x number default 0,
      pctile100x number default 0,
      pctile_score number default 0,
      -- # of times value is in range compared to the avg_val_ref.
      pct10x number default 0,
      pct20x number default 0,
      pct40x number default 0,
      pct80x number default 0,
      pct100x number default 0,
      pct120x number default 0,
      pct240x number default 0,
      pct480x number default 0,
      pct960x number default 0,
      pct1920x number default 0,
      pct9999x number default 0,
      pct_score number default 0,
      -- Historical max, min, and avg values are periodically updated here for reference.
      avg_val_ref number default 0 not null,
      -- Total number of calcs used to determine the avg_val_ref. Gives some idea of the sample size.
      avg_val_ref_calc_count number default 0 not null,
      -- Provides the name of the group which avg_val_ref is pulled from.
      avg_val_ref_group varchar2(12) default null,
      created timestamp(0) with time zone default systimestamp
      )', false);
      execute_sql('
      alter table stat_work add constraint pk_stat_work primary key (stat_work_id)', false);
      execute_sql('
      create unique index stat_work_1 on stat_work (stat_name, bucket_id)', false);
   end if;
   if not does_constraint_exist('stat_work_fk_bucket_id') then
      execute_sql('alter table stat_work add constraint stat_work_fk_bucket_id foreign key (bucket_id) references stat_bucket (bucket_id) on delete cascade', false);
   end if;
   if not does_column_exist('stat_work', 'pctile_score') then 
      execute_sql('alter table stat_work add pctile_score number default 0', false);
   end if;
   if not does_column_exist('stat_work', 'pct_score') then 
      execute_sql('alter table stat_work add pct_score number default 0', false);
   end if;
   if not does_column_exist('stat_work', 'neg_calc_count') then 
      execute_sql('alter table stat_work add neg_calc_count number default 0', false);
   end if;
   if not does_column_exist('stat_work', 'zero_calc_count') then 
      execute_sql('alter table stat_work add zero_calc_count number default 0', false);
   end if;
   if not does_column_exist('stat_work', 'stat_level') then 
      execute_sql('alter table stat_work add stat_level number default 0', false);
   end if;
end;
/

-- uninstall: exec drop_table('stat_avg_val_hist_ref');
begin
   if not does_table_exist('stat_avg_val_hist_ref') then 
      execute_sql('
      create table stat_avg_val_hist_ref (
      avg_val_ref_group varchar2(12),
      hist_key varchar2(12),
      bucket_id number,
      stat_name varchar2(250),
      row_count number,
      calc_count number,
      avg_val number,
      created timestamp(0) with time zone default systimestamp
      )', false);
      execute_sql('alter table stat_avg_val_hist_ref add constraint pk_stat_avg_val_hist_ref primary key (avg_val_ref_group, hist_key, bucket_id, stat_name)', false);
   end if;
   if not does_column_exist('stat_avg_val_hist_ref', 'calc_count') then 
      execute_sql('alter table stat_avg_val_hist_ref add calc_count number', false);
   end if;
end;
/

-- uninstall: exec drop_table('stat_percentiles_ref');
begin
   if not does_table_exist('stat_percentiles_ref') then 
      execute_sql('
      create table stat_percentiles_ref (
      bucket_id number,
      stat_name varchar2(250),
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
      created timestamp(0) with time zone default systimestamp
      )', false);
      execute_sql('alter table stat_percentiles_ref add constraint pk_stat_percentiles_ref primary key (bucket_id, stat_name)', false);
   end if;
end;
/

create or replace view v_stat_avg_val_hist_ref as 
select 'ALL' avg_val_ref_group,
       'ALL' hist_key,
       a.bucket_id,
       stat_name,
       sum(1) row_count,      
       sum(calc_count) calc_count,
       sum(calc_count*avg_val) calc_sum,
       round(avg(avg_val), 3) avg_val
  from stat_archive a,
       (select bucket_id, avg_val_hist_days from stat_bucket) b 
 where a.bucket_id=b.bucket_id 
   and a.stat_time >= trunc(a.stat_time)-b.avg_val_hist_days
 group
    by 'ALL',
       'ALL',
       a.bucket_id,
       stat_name
union all
select 'HH24',
       to_char(stat_time, 'HH24')||':00',
       a.bucket_id,
       stat_name,
       sum(1) row_count,
       sum(calc_count) calc_count,
       sum(calc_count*avg_val) calc_sum,
       round(avg(avg_val), 3) avg_val
  from stat_archive a,
       (select bucket_id, avg_val_hist_days from stat_bucket) b 
 where a.bucket_id=b.bucket_id 
   and a.stat_time >= trunc(a.stat_time)-b.avg_val_hist_days
 group
    by 'HH24',
       to_char(stat_time, 'HH24')||':00',
       a.bucket_id,
       stat_name
union all
select 'DY',
       to_char(stat_time, 'DY'),
       a.bucket_id,
       stat_name,
       sum(1) row_count,
       sum(calc_count) calc_count,
       sum(calc_count*avg_val) calc_sum,
       round(avg(avg_val), 3) avg_val
  from stat_archive a,
       (select bucket_id, avg_val_hist_days from stat_bucket) b 
 where a.bucket_id=b.bucket_id 
   and a.stat_time >= trunc(a.stat_time)-b.avg_val_hist_days
 group
    by 'DY',
       to_char(stat_time, 'DY'),
       a.bucket_id,
       stat_name;


-- uninstall: exec drop_table('stat_detail');
begin 
   if not does_table_exist('stat_detail') then 
      execute_sql('
      create table stat_detail (
      stat_detail_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      stat_name varchar2(250),
      bucket_id number,
      delta_val number default 0 not null,
      elapsed_seconds number default 0 not null,
      rate_per_second number,
      calc_type varchar2(12),
      calc_val number,
      pct_of_avg_val_ref number,
      avg_val_ref number,
      stat_time timestamp(0) with time zone,
      created timestamp(0) with time zone default systimestamp
      )', false);
      execute_sql('alter table stat_detail add constraint pk_stat_detail primary key (stat_detail_id)', false);
   end if;
   if not does_constraint_exist('stat_fk_bucket_id') then
      execute_sql('alter table stat_detail add constraint stat_fk_bucket_id foreign key (bucket_id) references stat_bucket (bucket_id) on delete cascade', false);
   end if;
end;
/

