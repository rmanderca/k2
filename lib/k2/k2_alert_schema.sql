

/*

Priorities are things like 'high', 'moderate', and 'low'.

Keep the # of priorities to a minimum.

Groups start with 5 priorities.

critical - 1: Usually means some service is unavailable or something very bad has happened. Immediate action required.

high, moderate and low - 2,3,4: These are the priorities that you use for things that usually need to be delbt with in a reasonable amount of time.

info - 5: This is for things that are not urgent and can be dealt with/or not at your convenience.

Zero is reserved for the 'disabled' priority.

Each priority has number of attributes that can be configured. See the alert_priorities table for more.

In theory this will be able to be run as a public service.

Anyone with access will be able to create multiple priority groups.

Each request will have a token associated with it. This identifies the requestor.

An specific id may belong to a requestor but have been made on behalf of a user of the requestor.

Requestor will be required to manage these relationships. 

API might look like

-- Create a new priority group
/api/v2/alerts/group/create

-- List my priority groups
/api/v2/alerts/group/list

-- Get a specific priority group
/api/v2/alerts/group/get/{id}

-- Update a priority group by modifying the results of a get
/api/v2/alerts/group/update/{id}

-- Delete a priority group
/api/v2/alerts/group/delete/{id}


*/

drop_table('alert_groups');

begin
   if app_dev.drop_tables then
      drop_table('alert_groups');
      drop_table('alert_priorities');
      drop_table('alerts');
   end if;
end;
/

-- uninstall: exec drop_table('alert_groups');
begin
   if not does_table_exist('alert_groups') then 
      execute_sql('
      create table alert_groups (
      group_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      -- Unique keys are required. Must be unique across all rows in the table.
      group_key varchar2(240) not null,
      -- Names are optional and only needed for reporting or if you want to make use of in a UI.
      group_name varchar2(240) default null,
      -- This is an optional reference which can be used by the developer.
      user_id number not null)', false);
   end if;
   add_pk_constraint('alert_groups', 'group_id');
   if not does_index_exist('alert_groups_1') then
      execute_sql('create unique index alert_groups_1 on alert_groups (group_key)', false);
   end if;
   if not does_constraint_exist('alert_groups_fk_user_id') then 
      execute_sql('alter table alert_groups add constraint alert_groups_fk_user_id foreign key (user_id) references saas_auth (user_id) on delete cascade', false);
   end if;
end;
/

-- uninstall: exec drop_table('alert_priorities');
begin
   if not does_table_exist('alert_priorities') then 
      execute_sql('
      create table alert_priorities (
      priority_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      group_id number not null,
      -- A number >=1. 5 is a lower priority than 1. Do not use 0, it is reserved.
      priority_level number not null,
      -- Assign a name to each priority level.
      priority_name varchar2(240) not null,
      -- Truthy values including cron expressions are allowed here.
      enabled varchar2(20) default ''Y'' not null,
      -- Can be a truthy value including cron expression. The highest default priority defined as a default is used.
      is_default varchar2(240) default null,
      -- Truthy values are allowed for most of the Y/N type columns if varchar2 length > 1.
      try_email varchar2(20) default ''Y'' not null,
      try_sms varchar2(20) default ''N'' not null,
      -- Send a reminder every N minutes. Backoff interval can make this value dynamic.
      reminders_interval number default 0 not null,
      reminders_interval_max number default 0 not null,
      reminders_interval_min number default 10 not null,
      reminder_try_email varchar2(20) default ''Y'' not null,
      reminder_try_sms varchar2(20) default ''N'' not null,
      -- How many reminders should be sent.
      reminder_count number default 0 not null,
      -- Reminder interval is multiplied by this value after each reminder to set the subsequent interval.
      reminder_backoff_interval number default 1 not null,
      abandon_interval number default 0 not null,
      abandon_try_email varchar2(240) default ''Y'' not null,
      abandon_try_sms varchar2(20) default ''N'' not null,
      close_interval number default 0 not null,
      close_try_email varchar2(20) default ''Y'' not null,
      close_try_sms varchar2(20) default ''N'' not null
      )', false);
   end if;
   add_pk_constraint('alert_priorities', 'priority_id');
   if not does_constraint_exist('alert_priorities_fk_group_id') then 
      execute_sql('alter table alert_priorities add constraint alert_priorities_fk_group_id foreign key (group_id) references alert_groups (group_id) on delete cascade', false);
   end if;
   if not does_index_exist('alert_priorities_1') then
      execute_sql('create unique index alert_priorities_1 on alert_priorities (group_id, priority_level)', false);
   end if;
end;
/

-- uninstall: exec drop_table('alerts');
begin
   if not does_table_exist('alerts') then 
      execute_sql('
      create table alerts (
      alert_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      priority_id number not null,
      -- If a key is not provided the key will be derived from the alert_text.
      alert_text varchar2(240),
      -- Unique key which identifies this alert and prevents duplicate alerts from being opened.
      alert_key varchar2(240),
      -- This will be: open, closed, or abandoned
      alert_status varchar2(20) not null,
      -- This is the priority level requested when the alert was originally opened. It may not be the priority that gets assigned.
      requested_priority_id number not null,
      opened timestamp default systimestamp,
      closed timestamp default null,
      try_email varchar2(1) default ''n'' not null,
      try_sms varchar2(1) default ''n'' not null,
      abandoned timestamp default null,
      reminder timestamp default null,
      -- Keeps track of the number of times the alert has triggered a reminder.
      reminders_count number default 0,
      reminders_interval number default 0,
      -- Last time alert was updated for a open, abandon, close or remind event. Primarily used as a sort order when reporting.
      last_event timestamp default systimestamp,
      last_event_type varchar2(20) default ''open'' not null,
      sent_email_count number default 0 not null
      )', false);
   end if;
   add_pk_constraint('alerts', 'alert_id');
   if not does_constraint_exist('alerts_fk_priority_id') then
      execute_sql('alter table alerts add constraint alerts_fk_priority_id foreign key (priority_id) references alert_priorities (priority_id) on delete cascade', false);
   end if;
   if not does_constraint_exist('alerts_fk_requested_priority_id') then
      execute_sql('alter table alerts add constraint alerts_fk_requested_priority_id foreign key (requested_priority_id) references alert_priorities (priority_id) on delete cascade', false);
   end if;
end;
/

-- uninstall: exec drop_view('alert_report_view');
create or replace view alert_report_view as (
select a.alert_id, 
       a.alert_key,
       c.group_key,
       b.priority_level, 
       b.priority_name,
       a.alert_status, 
       a.opened, 
       a.closed, 
       a.abandoned, 
       a.reminder,
       a.try_email, 
       a.try_sms,
       d.priority_level requested_priority_level,
       d.priority_name requested_priority_name
  from alerts a,
       alert_priorities b,
       alert_groups c,
       alert_priorities d
 where a.priority_id=b.priority_id
   and b.group_id=c.group_id
   and a.requested_priority_id=d.priority_id
   and (a.alert_status in ('open', 'abandoned')
    or (a.try_email='y' or a.try_sms='y')));
