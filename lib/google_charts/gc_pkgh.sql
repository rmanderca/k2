create or replace package gc is

   procedure start_series (
         p_series_id in varchar2);

   procedure add_chart (
      p_title in varchar2,
      p_vaxis_title in varchar2 default '',
      p_haxis_title in varchar2 default '',
      p_scale_type in varchar2 default 'linear',
      p_line_width in number default 1,
      p_line_color in varchar2 default 'black',
      p_width in number default 600,
      p_height in number default 400,
      p_background_color in varchar2 default 'white',
      p_tags in varchar2 default null,
      p_div_group in number default 0);

   procedure add_column (
      p_data_type in varchar2,
      p_column_name in varchar2);

   procedure add_data (
      p_data in varchar2);

   procedure end_chart;

   procedure end_series;

   function get_js_chunk return varchar2;

   function get_js return clob;

   function get_divs (
      p_series_id in varchar2,
      p_div_group in number default null,
      p_set_class in varchar2 default 'gc',
      p_having_tags in varchar2 default null) return clob;
   
end;
/
