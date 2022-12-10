
-- uninstall: exec drop_package('k2_metrics');
create or replace package k2_metrics as 

	procedure get_metrics;

end;
/
