-- uninstall: drop package statzilla;
create or replace package statzilla as 

g_bucket stat_bucket%rowtype;

procedure add_bucket ( 
   p_bucket_name in varchar2,
   p_calc_type in varchar2 default 'none',
   p_ignore_negative in varchar2 default 'N',
   p_save_stat_hours in number default 0,
   p_skip_archive_hours in number default 0);

function get_bucket (
   p_bucket_id in number) return stat_bucket%rowtype;

function get_bucket_by_name (
   p_bucket_name in varchar2) return stat_bucket%rowtype;

procedure save_bucket (
   p_bucket in stat_bucket%rowtype);

function does_bucket_exist (
   p_bucket_name in varchar2) return boolean;

procedure refresh_references (
   p_bucket_id in varchar2,
   p_stat_name in varchar2);

procedure refresh_all_references;

procedure refresh_avg_val_hist_ref (
   p_bucket_id in varchar2,
   p_stat_name in varchar2);

procedure refresh_stat_percentiles_ref (
   p_bucket_id in varchar2,
   p_stat_name in varchar2);

procedure process_buckets;

procedure process_bucket (p_bucket_name in varchar2);

procedure process_bucket_time (p_bucket_name in varchar2, p_stat_time in timestamp with time zone);

procedure get_new_stats (p_bucket_id in number);

procedure purge_stats (
   p_bucket_id in varchar2, 
   p_stat_name in varchar2);

procedure delete_bucket (
   p_bucket_id in varchar2);

-- procedure purge_bucket (p_bucket_id in varchar2);

end;
/
