-- uninstall: drop package arcsql_default_setting;
create or replace package arcsql_default_setting as 

   -- ArcSQL purges data from audsid_event table older than X hours.
   purge_event_hours number := 4;

   -- ==== Optional Library Configuration Values ====

   -- The following sections are for optional libraries that may or may not
   -- be installed. If they are you should set these values in your private 
   -- arcsql_instance package header.

   -- SENDGRID 
   -- Your SendGrid API key.
   sendgrid_api_key varchar2(120) := '';
   -- "from address" to use. Use the domain you set up with SendGrid.
   sendgrid_from_address varchar2(120) := '';

end;
/



