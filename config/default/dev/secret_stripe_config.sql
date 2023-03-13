
-- uninstall: exec drop_package('stripe_config');
create or replace package stripe_config as 
   publishable_key varchar2(128) := 'pk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
   secret_api_key varchar2(128) := 'sk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
   api_url varchar2(128) := 'https://api.stripe.com/v1';	
end;
/
