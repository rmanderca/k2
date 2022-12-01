
-- IMPORTANT: The files below should be idempotent (https://en.wikipedia.org/wiki/Idempotence).

-- WARNING: You may want to exclude files starting with secret* from git. See the .gitignore file.

@../../../config/&k2_app_dir/&k2_env_dir/secret_arcsql_cfg.sql
@../../../config/&k2_app_dir/&k2_env_dir/secret_k2_config.sql
@../../../config/&k2_app_dir/&k2_env_dir/secret_saas_auth_config.sql 
@../../../config/&k2_app_dir/&k2_env_dir/secret_app_config.sql

-- Authentication (create account, verify email, login, forgot password) features.
@saas_auth_events.sql

-- Automatically pre-create users you need for your app.
@users.sql

-- send_email procedure over-ride. Replace the delivery proc with your proc to interface with your email solution.
@send_email.sql

-- Things that need to run towards the end of the install.
@saas_app_post_install.sql

-- Install any scheduled jobs using the dbms job scheduler.
@app_scheduler_jobs.sql

commit;

select 'APP install complete.' message from dual;
