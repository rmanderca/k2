

create or replace trigger dataset_before_insert_or_update_trg 
   before insert or update on dataset for each row
begin
   :new.calc_type := lower(:new.calc_type);
   :new.metric_interval_date_format := upper(:new.metric_interval_date_format);
   :new.avg_target_group := upper(:new.avg_target_group);
end;
/

-- create or replace trigger metric_before_insert_trg
--    before insert on metric for each row
-- begin
--    -- If static json was not provided then see if it is embeded 
--    if :new.static_json is null and instr(:new.metric_name, '{"') > 0 then
--       -- :new.static_json := json_scalar(trim(substr(:new.metric_name, instr(:new.metric_name, '{"'))));
--       :new.static_json := trim(substr(:new.metric_name, instr(:new.metric_name, '{"')));
--    end if;
-- exception
--    when others then
--       dbms_output.put_line(dbms_utility.format_error_stack);
--       raise;
-- end;
-- /

create or replace trigger metric_work_before_insert_trg
   before insert on metric_work for each row 
begin
   -- Do not do below, should already be set by the invoker. 
   -- k2_metric.set_dataset_by_id(:new.dataset_id);
   null;
end;
/

create or replace trigger metric_in_before_insert_trg 
   before insert on metric_in for each row
declare
begin
   if :new.metric_time is null then 
      :new.metric_time := systimestamp;
   end if;
   if :new.metric_key is null then 
      :new.metric_key := :new.metric_name;
   end if;
   if :new.metric_name is null then 
      :new.metric_name := :new.metric_key;
   end if;
   -- Do not allow single ticks.
   :new.metric_key := replace(:new.metric_key, '''', '_');
   :new.metric_name := replace(:new.metric_name, '''', '_');
   -- If the dataset_id is not provided user can provide the key or a token instead
   if :new.dataset_key is not null then 
       select dataset_id into :new.dataset_id from dataset where dataset_key=:new.dataset_key;
   elsif :new.dataset_token is not null then 
      select token_alt_id into :new.dataset_id from tokens where token=:new.dataset_token;
   end if;
   :new.metric_id := arcsql.str_to_base64(:new.dataset_id || :new.metric_key);
exception
   when others then
      dbms_output.put_line(dbms_utility.format_error_stack);
      raise;
end;
/

