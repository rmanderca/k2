create or replace package gc is

   procedure start_series (
         p_series_id in varchar2);

   procedure add_chart (
      p_title in varchar2,
      p_vaxis_title in varchar2 default '',
      p_haxis_title in varchar2 default '',
      p_scale_type in varchar2 default 'linear',
      p_line_width in number default 1,
      p_line_color in varchar2 default 'black');

   procedure add_column (
      p_data_type in varchar2,
      p_column_name in varchar2);

   procedure add_data (
      p_data in varchar2);

   procedure end_chart;

   procedure end_series;

   function get_js_chunk return varchar2;

   function get_js return clob;

   function get_divs return clob;
end;
/
