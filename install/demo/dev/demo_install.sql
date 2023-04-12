
define k2_app_dir="demo"
define k2_env_dir="dev"
define k2_lib_dir="lib"
@../../../_k2_install.sql
@../../../app/&k2_app_dir/&k2_env_dir/demo_install.sql
-- ToDo: Think about the validity of always running this. Maybe only perform the action at actual app level and flag driven.
-- exec fix_identity_sequences;
commit;

