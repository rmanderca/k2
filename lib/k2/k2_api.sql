
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

   ords.define_module (
      p_module_name=>'api_v1',
      p_base_path=>'/api/v1/',
      p_items_per_page=>1000,
      p_status=>'PUBLISHED',
      p_comments=>'API for K2');

   ords.define_template (
      p_module_name=>'api_v1',
      p_pattern=>'status',
      p_comments=>'API status check');

   -- Should be available at https://k2.maxapex.net/apex/cddev/api/status
   -- ords.define_handler (
   --    p_module_name=>'api',
   --    p_pattern=>'status',
   --    p_method=>'GET',
   --    p_mimes_allowed => '',
   --    p_source_type=>ords.source_type_query_one_row,
   --    p_source=>
   --    'select ''ok'' message from dual');

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
