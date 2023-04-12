-- uninstall: exec drop_package('chatgpt_config');
create or replace package chatgpt_config as 
   secret_api_key varchar2(128) := 'sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';	
end;
/
