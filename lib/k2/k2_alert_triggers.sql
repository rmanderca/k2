create or replace trigger alert_priority_groups_insert_trg 
   before insert on alert_priority_groups for each row
begin
   arcsql.assert_str_is_key_str(:new.alert_priority_group_key);
end;
/


create or replace trigger alert_priority_groups_after_insert_trg 
   after insert on alert_priority_groups for each row
begin
   arcsql.assert_str_is_key_str(:new.alert_priority_group_key);
   k2_alert.add_default_rows_to_new_group(p_alert_priority_group_id=>:new.alert_priority_group_id);
end;
/
