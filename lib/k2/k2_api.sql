
declare 

   v1_base_path varchar2(120) := k2_config.api_base_path || '/v1/';

begin

   if k2_config.enable_ords then 
      if not ords_is_enabled then
         ords.enable_schema;
      end if;
   else
      if ords_is_enabled then
         ords.enable_schema(false);
      end if;
   end if;

   ords.delete_module(
      p_module_name=>'api_v1');

   ords.define_module (
      p_module_name=>'api_v1',
      p_base_path=>v1_base_path,
      p_items_per_page=>1000,
      p_status=>'PUBLISHED',
      p_comments=>'API for K2');

   ords.define_template (
      p_module_name=>'api_v1',
      p_pattern=>'status',
      p_comments=>'API status check');

   ords.define_handler (
      p_module_name=>'api_v1',
      p_pattern=>'status',
      p_method=>'GET',
      p_mimes_allowed => '',
      p_source_type=>ords.source_type_plsql,
      p_source=>'begin k2_api.status_v1; end;');

   commit;

end;
/
