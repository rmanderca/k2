create or replace package body k2_alert as 

function to_priority_group_id (
   p_priority_group_key in varchar2)
   return number is
   n number;
begin
   select priority_group_id into n from alert_priority_groups where priority_group_key = p_priority_group_key;
   return n;
end;

function get_open_alert_id ( -- | Returns alert_id or null if the alert is not found or is not open (overloaded).
   p_priority_group_id in number,
   p_alert_text in varchar2) return number is 
   n number;
begin
   select max(alert_id) into n
     from alerts a,
          alert_priorities b,
          alert_priority_groups c
    where a.priority_id=b.priority_id
      and b.priority_group_id=c.priority_group_id 
      and a.alert_text=p_alert_text
      and a.alert_status in ('open', 'abandoned');
   return n;
end;

function get_open_alert_id ( -- | Returns alert_id or null if the alert is not found or is not open (overloaded).
   p_alert_key in varchar2) 
   return number is 
   n number;
begin
   select max(alert_id) into n
     from alerts a,
          alert_priorities b,
          alert_priority_groups c
    where a.priority_id=b.priority_id
      and b.priority_group_id=c.priority_group_id 
      and a.alert_key=p_alert_key
      and a.alert_status in ('open', 'abandoned');
   return n;
end;

function get_alert_priority_row ( -- | Returns a row from alert_priorities.
   p_priority_id in number) 
   return alert_priorities%rowtype is 
   r alert_priorities%rowtype;
begin 
   k2.debug('get_alert_priority_row: '||p_priority_id);
   select * into r 
     from alert_priorities 
    where priority_id=p_priority_id;
   return r;
end;

function is_open ( -- | Return true if the alert is open (overloaded).
   p_priority_group_id in number,
   p_alert_text in varchar2) return boolean is 
   v_alert_id number;
begin 
   v_alert_id := get_open_alert_id(p_priority_group_id, p_alert_text);
   if v_alert_id is not null then
      return true;
   else
      return false;
   end if;
end;

function is_open ( -- | Return true if the alert is open (overloaded).
   p_alert_key in varchar2) return boolean is 
   v_alert_id number;
begin 
   v_alert_id := get_open_alert_id(p_alert_key);
   if v_alert_id is not null then
      return true;
   else
      return false;
   end if;
end;

function get_alert_row ( -- | Return a row from the alerts table.
   p_alert_id in number)
   return alerts%rowtype is
   r alerts%rowtype;
begin
   select * into r from alerts where alert_id=p_alert_id;
   return r;
end;

function get_priority_group_row ( -- | Return a row from the alert_priority_groups table.
   p_priority_group_id in number)
   return alert_priority_groups%rowtype is 
   r alert_priority_groups%rowtype;
begin
   select * into r from alert_priority_groups where priority_group_id=p_priority_group_id;
   return r;
end;

function get_priority_group_id ( -- Return id for the priority group key.
   p_priority_group_key in varchar2) return number is 
   n number;
begin
   select priority_group_id into n from alert_priority_groups where priority_group_key=p_priority_group_key;
   return n;
end;

procedure close_alert_by_id ( -- | Used by the two overloads below.
   p_alert_id in number) is 
   v_alert_priority_row alert_priorities%rowtype;
begin 
   v_alert_priority_row := get_alert_priority_row(get_alert_row(p_alert_id).priority_id);
   update alerts 
      set closed=systimestamp, 
          alert_status='closed',
          try_email=decode(try_email, 'y', 'y', arcsql.is_truthy_y(v_alert_priority_row.close_try_email)),
          try_sms=decode(try_sms, 'y', 'y', arcsql.is_truthy_y(v_alert_priority_row.close_try_sms)),
          last_event=systimestamp,
          last_event_type='closed'
    where alert_id=p_alert_id;
end;

procedure close_alert (
   p_priority_group_id in number,
   p_alert_text in varchar2) is 
   v_alert_id number;
begin 
   v_alert_id := get_open_alert_id(p_priority_group_id, p_alert_text);
   if v_alert_id is not null then 
      close_alert_by_id(p_alert_id=>v_alert_id);   
   end if;
end;

procedure close_alert (
   p_alert_key in varchar2) is 
   v_alert_id number;
begin 
   v_alert_id := get_open_alert_id(p_alert_key);
   if v_alert_id is not null then 
      close_alert_by_id(p_alert_id=>v_alert_id);   
   end if;
end;

procedure abandon_alert (
   p_alert_id in number) is 
   v_alert_priority_row alert_priorities%rowtype;
begin 
   v_alert_priority_row := get_alert_priority_row(get_alert_row(p_alert_id).priority_id);
   update alerts 
      set abandoned=systimestamp, 
          alert_status='abandoned',
          try_email=decode(try_email, 'y', 'y', arcsql.is_truthy_y(v_alert_priority_row.abandon_try_email)),
          try_sms=decode(try_sms, 'y', 'y', arcsql.is_truthy_y(v_alert_priority_row.abandon_try_sms)),
          last_event=systimestamp,
          last_event_type='abandoned'
    where alert_id=p_alert_id;
end;

procedure autoclose_alert (
   p_alert_id in number) is 
   v_alert_priority_row alert_priorities%rowtype;
begin 
   v_alert_priority_row := get_alert_priority_row(get_alert_row(p_alert_id).priority_id);
   update alerts 
      set closed=systimestamp, 
          alert_status='autoclosed',
          try_email=decode(try_email, 'y', 'y', arcsql.is_truthy_y(v_alert_priority_row.close_try_email)),
          try_sms=decode(try_sms, 'y', 'y', arcsql.is_truthy_y(v_alert_priority_row.close_try_sms)),
          last_event=systimestamp,
          last_event_type='autoclosed'
    where alert_id=p_alert_id;
end;

function get_reminder_backoff_interval (
   p_priority_id in number)
   return number is 
   n number;
begin 
   select reminder_backoff_interval into n
     from alert_priorities
    where priority_id=p_priority_id;
   return n;
end;

procedure remind_alert (
   p_alert_id in number) is 
   v_alert alerts%rowtype;
   v_reminder_backoff_interval number;
   v_alert_priority_row alert_priorities%rowtype;
begin 
   v_alert_priority_row := get_alert_priority_row(get_alert_row(p_alert_id).priority_id);
   v_alert := get_alert_row(p_alert_id);
   v_reminder_backoff_interval := get_reminder_backoff_interval(v_alert.priority_id);
   update alerts 
      set reminders_interval=reminders_interval*v_reminder_backoff_interval,
          reminders_count=reminders_count+1,
          reminder=systimestamp,
          try_email=arcsql.is_truthy_y(v_alert_priority_row.reminder_try_email),
          try_sms=arcsql.is_truthy_y(v_alert_priority_row.reminder_try_sms),
          last_event=systimestamp,
          last_event_type='reminder'
    where alert_id=p_alert_id;
end;

procedure create_alert_priority ( -- | Adds a single alert priority to a priority group.
   p_priority_group_id in number,
   p_priority_name in varchar2,
   p_priority_level in number) is 
begin 
   k2.debug2('create_alert_priority: '||p_priority_group_id||', '||p_priority_name||', '||p_priority_level);
   insert into alert_priorities (
      priority_group_id,
      priority_level,
      priority_name) values (
      p_priority_group_id,
      p_priority_level,
      p_priority_name);
end;

procedure add_default_rows_to_new_priority_group ( -- | Adds default priorities to a new priority group.
   p_priority_group_id in number) is 
   n number;
begin 
   k2.debug('add_default_rows_to_new_priority_group: '||p_priority_group_id);
   select count(*) into n from alert_priorities where priority_group_id=p_priority_group_id;
   if n = 0 then 
      create_alert_priority(p_priority_group_id=>p_priority_group_id, p_priority_name=>'critical', p_priority_level=>1);
      create_alert_priority(p_priority_group_id=>p_priority_group_id, p_priority_name=>'high', p_priority_level=>2);
      create_alert_priority(p_priority_group_id=>p_priority_group_id, p_priority_name=>'moderate', p_priority_level=>3);
      create_alert_priority(p_priority_group_id=>p_priority_group_id, p_priority_name=>'low', p_priority_level=>4);
      create_alert_priority(p_priority_group_id=>p_priority_group_id, p_priority_name=>'info', p_priority_level=>5);
      update alert_priorities set is_default='Y' 
       where priority_group_id=p_priority_group_id and priority_level=3;
   end if;
end;

procedure create_priority_group ( -- | Creates a priority group if it does not exist.
   p_priority_group_key in varchar2, -- | Caller must provide a unique key to identify the priority group. Must be unique across the entire table.
   p_priority_group_name in varchar2, -- | Name of the priority group.
   p_user_id in number) is -- | References saas_auth table.
   v_priority_group_id number;
   n number;
begin 
   k2.debug('create_priority_group: '||p_priority_group_key||', '||p_priority_group_name||', '||p_user_id);
   select count(*) into n from alert_priority_groups where priority_group_key=p_priority_group_key;
   if n = 0 then
      insert into alert_priority_groups (priority_group_key, priority_group_name, user_id)
      values (p_priority_group_key, p_priority_group_name, p_user_id) returning priority_group_id into v_priority_group_id;
      add_default_rows_to_new_priority_group(v_priority_group_id);
   end if;
end;

function does_priority_group_exist (
   p_priority_group_key in varchar2)
   return boolean is 
   n number;
begin 
   select count(*) into n from alert_priority_groups where priority_group_key=p_priority_group_key;
   if n = 1 then 
      return true;
   else
      return false;
   end if;
end;

procedure delete_priority_group (
   p_priority_group_key in varchar2)
   is 
begin 
   delete from alert_priority_groups where priority_group_key=p_priority_group_key;
end;   

function get_max_allowed_priority_row ( -- | Returns the highest available priority available per the level requested.
   p_priority_id in number
   ) return alert_priorities%rowtype is
   max_allowed_priority number;
   r alert_priorities%rowtype;
begin
   select * into r 
     from alert_priorities where priority_id=p_priority_id;

   select max(priority_level) into max_allowed_priority
     from alert_priorities
    where priority_level <= r.priority_level
      and priority_group_id=r.priority_group_id
      and arcsql.is_truthy_y(enabled) = 'y';

   if max_allowed_priority is null then
      return null;
   end if;

   select * into r
     from alert_priorities
    where priority_level=max_allowed_priority
      and priority_group_id=r.priority_group_id;

   return r;

end;

procedure open_alert ( -- | Open a new alert if it is not already open.
   p_priority_group_id in number, -- | Alerts must be linked to a priority group.
   p_alert_text in varchar2, -- | ALert text is used to build a unique key if key is not provided.
   p_priority_level in number default 3, -- | A valid level within the provided priority group.
   p_alert_key in varchar2 default null -- | A unique key to identify the alert. If not provided, a unique key is generated from p_alert_text.
   ) is 
   v_alert_key alerts.alert_key%type := nvl(p_alert_key, arcsql.str_to_key_str(p_alert_text));
   v_requested_priority_row alert_priorities%rowtype;
   v_actual_priority_row alert_priorities%rowtype;
   v_alert_id number;
begin 
   if not is_open(p_alert_key=>v_alert_key) then 
      select * into v_requested_priority_row
        from alert_priorities
       where priority_group_id=p_priority_group_id 
         and priority_level=p_priority_level;
      v_actual_priority_row := get_max_allowed_priority_row(v_requested_priority_row.priority_id);
      insert into alerts (
         priority_id,
         alert_text,
         alert_key,
         alert_status,
         requested_priority_id,
         reminders_interval,
         try_email,
         try_sms) values (
         v_actual_priority_row.priority_id,
         p_alert_text,
         v_alert_key,
         'open',
         v_requested_priority_row.priority_id,
         v_actual_priority_row.reminders_interval,
         arcsql.is_truthy_y(v_actual_priority_row.try_email),
         arcsql.is_truthy_y(v_actual_priority_row.try_sms)) returning alert_id into v_alert_id;
   end if;
exception
   when others then
      k2.log_err('open_alert: '||dbms_utility.format_error_stack);
      raise;
end;

procedure check_alerts is -- | Checks all open alerts to see if a new entry needs to be written to the alert log.
   cursor alerts is 
   select *
     from alerts 
    where alert_status in ('open', 'abandoned');
   v_new_priority_row alert_priorities%rowtype;
   v_old_priority_row alert_priorities%rowtype;
begin 
   if is_truthy(app_job.disable_all) or not is_truthy(app_job.enable_k2_alert_checks)) then 
      return;
   end if;
   for alert in alerts loop 
      v_old_priority_row := get_alert_priority_row(alert.priority_id);
      v_new_priority_row := get_max_allowed_priority_row(alert.requested_priority_id);
      if v_new_priority_row.priority_level <> v_old_priority_row.priority_level then 
         alert.priority_id := v_new_priority_row.priority_id;
         alert.reminders_interval := v_new_priority_row.reminders_interval;
         update alerts set row=alert where alert_id=alert.alert_id;
         if v_new_priority_row.priority_level < v_old_priority_row.priority_level then 
            -- Throw a new open event if the priority is higher (1 is higher than 5).
            update alerts 
               set alert_status='open',
                   try_email=decode(try_email, 'y', 'y', arcsql.is_truthy_y(v_new_priority_row.try_email)),
                   try_sms=decode(try_sms, 'y', 'y', arcsql.is_truthy_y(v_new_priority_row.try_sms)),
                   last_event=systimestamp,
                   last_event_type='open';
         end if;
      elsif v_new_priority_row.close_interval > 0 and alert.opened+(v_new_priority_row.close_interval/1440) < systimestamp then 
         autoclose_alert(alert.alert_id);
      elsif v_new_priority_row.abandon_interval > 0 and alert.opened+(v_new_priority_row.abandon_interval/1440) < systimestamp and alert.alert_status = 'open' then 
         abandon_alert(alert.alert_id);
      elsif v_new_priority_row.reminders_interval > 0 and alert.reminder+(v_new_priority_row.reminders_interval/1440) < systimestamp and alert.reminders_count < alert.reminders_count and alert.alert_status = 'open' then 
         remind_alert(alert.alert_id);
      end if;
   end loop;
   commit;
exception
   when others then
      k2.log_err('check_alerts: '||dbms_utility.format_error_stack);
      raise;
end;

end;
/
