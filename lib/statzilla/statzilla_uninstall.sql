-- NOTE: This file is generated by build_app_uninstall.sql.
drop table stat_calc_type cascade constraints purge;
exec drop_table('stat_profile');
exec drop_table('stat_bucket');
exec drop_table('stat');
exec drop_table('stat_property');
exec drop_table('stat_in');
exec drop_table('stat_archive');
drop sequence seq_stat_work_id;
exec drop_table('stat_work');
exec drop_table('stat_avg_val_hist_ref');
exec drop_table('stat_percentiles_ref');
exec drop_table('stat_detail');
drop package statzilla;
exec drop_scheduler_job('statzilla_process_buckets_job');
exec drop_scheduler_job('statzilla_get_oracle_metrics_job');
exec drop_scheduler_job('statzilla_refresh_references_job');
