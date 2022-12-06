-- uninstall: drop package statzilla;
create or replace package statzilla as 

g_bucket stat_bucket%rowtype;

procedure create_bucket ( 
   p_bucket_key in varchar2,
   p_bucket_name in varchar2,
   p_user_id in number,
   p_calc_type in varchar2 default 'none',
   p_ignore_negative in number default 0,
   p_save_stat_hours in number default 0,
   p_skip_archive_hours in number default 0);

procedure save_bucket (
   p_bucket in stat_bucket%rowtype);

function does_bucket_exist (
   p_bucket_key in varchar2) return boolean;

procedure process_buckets;

procedure purge_stats (
   p_bucket_id in varchar2, 
   p_stat_key in varchar2);

procedure delete_bucket (
   p_bucket_id in varchar2);

procedure refresh_references ( 
   p_bucket_id in varchar2,
   p_stat_key in varchar2);

procedure refresh_all_references;

function get_bucket_row ( 
   p_bucket_key in varchar2) return stat_bucket%rowtype;

-- procedure purge_bucket (p_bucket_id in varchar2);

end;
/
