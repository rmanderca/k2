

-- ToDo: REMOVE ME
-- uninstall: exec drop_table('pricing_plans');
begin
   if not does_table_exist('pricing_plans') then 
      execute_sql('
      create table pricing_plans (
      pricing_plan_id number generated by default on null as identity cache 20 noorder nocycle nokeep noscale not null,
      pricing_plan_name varchar2(255) not null,
      user_id number default null,
      

      )');
   end if;
end;
/

