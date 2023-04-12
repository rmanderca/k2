create or replace package gc is

   g_chart_count number := 0;
   
   procedure start_series (
         p_series_id in varchar2);

   procedure add_column (
      p_data_type in varchar2,
      p_column_name in varchar2);

   procedure add_data (
      p_data1 in varchar2,
      p_data2 in varchar2 default null,
      p_data3 in varchar2 default null,
      p_data4 in varchar2 default null,
      p_data5 in varchar2 default null);

   procedure add_line_chart (
      p_title in varchar2,
      p_vaxis_title in varchar2 default '',
      p_haxis_title in varchar2 default '',
      p_scale_type in varchar2 default 'linear',
      p_line_width in number default 1,
      p_line_color in varchar2 default 'blue, gray, green, black, red, yellow, orange, purple, brown, pink',
      p_width in number default 600,
      p_height in number default 400,
      p_background_color in varchar2 default 'white',
      p_tags in varchar2 default null,
      p_div_group in varchar2 default 'default',
      p_url in varchar2 default null);

   procedure end_series;

   function get_js (
      p_series_id in varchar2)
      return clob;

   function get_divs (
      p_series_id in varchar2,
      p_div_group in varchar2 default 'default',
      p_having_div_tags in varchar2 default null,
      p_set_class in varchar2 default 'google_charts')
      return clob;
end;
/
