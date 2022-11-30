
@stripe_schema.sql
@stripe_pkgh.sql
@stripe_pkgb.sql

begin

   ords.define_module (
      p_module_name=>'stripe.v1',
      p_base_path=>'/stripe/v1/',
      p_items_per_page=>100,
      p_status=>'PUBLISHED',
      p_comments=>'Stripe API');

   ords.define_template (
      p_module_name=>'stripe.v1',
      p_pattern=>'webhooks',
      p_comments=>'Stripe Webhooks');

   ords.define_handler (
      p_module_name=>'stripe.v1',
      p_pattern=>'webhooks',
      p_method=>'POST',
      p_mimes_allowed => 'application/json',
      p_source_type=>'plsql/block',
      p_source=>'
      begin
         arcsql.debug(''stripe: '');
         insert into stripe_webhooks (
            event_request_body) values (
            :body_text);
         commit;
         :status_code := 200; 
      exception
         when others then
            arcsql.log_err(sqlerrm);
            :status_code := 400;
            :errmsg := sqlerrm;  
      end;');

   -- ords.define_parameter (
   --    p_module_name        => 'stripe.v1',
   --    p_pattern            => 'webhooks',
   --    p_method             => 'POST',
   --    p_name               => 'api_version',
   --    p_bind_variable_name => 'api_version',
   --    p_source_type        => 'HEADER',
   --    p_param_type         => 'STRING',
   --    p_access_method      => 'IN',
   --    p_comments           => null);

   commit;
end;
/

