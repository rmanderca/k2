create or replace package body gc is 

type div_row is record (
   div_text varchar2(4096),
   div_tags varchar2(256),
   div_group varchar2(256));
type div_table is table of div_row;
-- Must be initialized like this or we get ORA-06531: Reference to uninitialized collection
g_divs_clob clob;
g_div_rows div_table := div_table();

g_series_id varchar2(256);

g_chunk_pos number := 1;
g_chunk_amount number := 20000;

-- Reset for each new series.
g_charts_js clob;

g_functions clob;
g_charts clob;
g_callbacks clob;
-- True if we are in the midst of a series
g_series_in_progress boolean := false;

-- Most reset for each new chart.
g_function varchar2(4000);
g_function_name varchar2(256);
g_columns varchar2(4000);
g_column_count number := 0;
g_lock_column_count boolean := false;
g_data clob;
g_row_count number := 0;
g_options clob;
g_div_name clob;
g_title varchar2(256);
g_width number := 600;
g_height number := 400;
g_chart_in_progress boolean := false;
g_vaxis_title varchar2(256) := '';
g_haxis_title varchar2(256) := '';
g_scale_type varchar2(256);
g_line_width number default 1;
g_line_color varchar2(256);
g_background_color varchar2(256);

procedure assert_column_count_is_not_locked is
begin
   if g_lock_column_count then
      raise_application_error(-20001, 'Column count is locked.');
   end if;
end;

procedure assert_series_is_started is 
begin 
   if not g_series_in_progress then 
      raise_application_error(-20001, 'Google Chart series not in progress!');
   end if;
end;

procedure assert_chart_is_defined is 
begin
   if not g_chart_in_progress then 
      raise_application_error(-20002, 'Google Chart not in progress!');
   end if;
end;

procedure assert_columns_are_defined is 
begin
   if g_column_count = 0 then 
      raise_application_error(-20001, 'Columns need to be defined first!');
   end if;
end;

procedure assert_chart_has_data is 
begin
   if g_row_count = 0 then 
      raise_application_error(-20001, 'Chart does not have any data points!');
   end if;
end;

procedure assert_chart_count_is_not_zero is 
begin
   if g_chart_count = 0 then 
      raise_application_error(-20001, 'Chart count is zero!');
   end if;
end;

procedure assert_series_id_has_not_changed (
   p_series_id in varchar2) is 
begin 
   if p_series_id != g_series_id then 
      raise_application_error(-20001, 'Series id has changed!');
   end if;
end;

function series_template return varchar2 is
begin
   return '
   <script src="https://www.gstatic.com/charts/loader.js"></script>
   <script>
   console.log("Loading Google Charts...");
   google.charts.load(''current'', {''packages'':[''corechart'', ''line'']});
   #CALLBACKS#
   #FUNCTIONS#
   </script>
';
end;

function callback_template return varchar2 is
begin
   return 
'google.charts.setOnLoadCallback(#FUNCTION_NAME#);
';
end;

function function_template return varchar2 is
begin 
   -- ToDo:
   -- trendlines: {
   --    0: {type: ''polynomial'', color: ''gray'', opacity: 1, degree: 5},
   -- },
   return 
'function #FUNCTION_NAME#() {
   console.log("#FUNCTION_NAME#");
   var data = new google.visualization.DataTable();
   #COLUMNS#
   data.addRows([#DATA#]);
   var options = {
      title:''#TITLE#'',
      width: #WIDTH#,
      height: #HEIGHT#,
      colors: [''#LINE_COLOR#''],
      legend: ''none'',
      backgroundColor: ''#BACKGROUND_COLOR#'',
      scaleType: ''#SCALE_TYPE#'',
      lineWidth: #LINE_WIDTH#,
      hAxis: {
         title: ''#HAXIS_TITLE#''
      },
      vAxis: {
         title: ''#VAXIS_TITLE#''
      }};
   var chart = new google.visualization.LineChart(document.getElementById(''#DIV_NAME#''));
   chart.draw(data, options);
}
';
end;

procedure init_chart_defaults is 
begin
   arcsql.debug2('init_chart_defaults');
   g_function := null;
   g_function_name := null;
   g_data := null;
   g_options := null;
   g_div_name := null;
   g_title := null;
   g_width := 600;
   g_height := 400;
   g_row_count := 0;
   g_vaxis_title := '';
   g_haxis_title := '';
   g_scale_type := 'linear';
   g_line_width := 1;
   g_line_color := 'black';
   g_background_color := 'white';
   g_chart_in_progress := false;
end;

procedure init_series_defaults is -- | Initialize global variables before we start building a series of charts.
begin 
   arcsql.debug2('init_series_defaults');
   g_series_id := null;
   g_charts_js := null;
   g_chart_count := 0;

   g_div_rows.delete;

   g_functions := null;
   g_charts := null;
   g_callbacks := null;
   g_columns := null;
   g_series_in_progress := false;
   g_lock_column_count := false;
   init_chart_defaults;
end;

-- Everything above this line is private.

procedure start_series ( -- | Begin building some charts.
   p_series_id in varchar2 -- | This value will be used later to make sure we are still working with out data since we are using a lot of globals.
   ) is 
begin
   arcsql.debug2('start_series');
   init_series_defaults;
   g_series_id := p_series_id;
   g_series_in_progress := true;
end;

procedure end_chart is 
begin 
   arcsql.debug2('end_chart');
   assert_series_is_started;
   assert_columns_are_defined;
   assert_chart_is_defined;
   assert_chart_has_data;
   g_function := replace(function_template, '#FUNCTION_NAME#', g_function_name);
   g_function := replace(g_function, '#DIV_NAME#', g_div_name);
   g_function := replace(g_function, '#COLUMNS#', g_columns);
   g_function := replace(g_function, '#TITLE#', g_title);
   g_function := replace(g_function, '#WIDTH#', g_width);
   g_function := replace(g_function, '#HEIGHT#', g_height);
   g_function := replace(g_function, '#VAXIS_TITLE#', g_vaxis_title);
   g_function := replace(g_function, '#HAXIS_TITLE#', g_haxis_title);
   g_function := replace(g_function, '#SCALE_TYPE#', g_scale_type);
   g_function := replace(g_function, '#LINE_WIDTH#', g_line_width);
   g_function := replace(g_function, '#LINE_COLOR#', g_line_color);
   g_function := replace(g_function, '#BACKGROUND_COLOR#', g_background_color);
   g_functions := g_functions || arcsql.clob_replace(to_clob(g_function), to_clob('#DATA#'), rtrim(g_data, ','));
   g_chart_in_progress := false;
end;

procedure add_line_chart ( -- | Start creating a new chart.
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
   p_div_group in varchar2 default 'default',
   p_url in varchar2 default null) is 
begin
   arcsql.debug2('add_line_chart: p_title='||p_title||', p_div_group='||p_div_group);
   assert_series_is_started;
   assert_columns_are_defined;
   if g_chart_in_progress then
      end_chart;
   end if;
   init_chart_defaults;
   g_chart_in_progress := true;
   g_chart_count := g_chart_count + 1;
   -- Lock columns if not already locked.
   g_lock_column_count := true;
   g_function_name := arcsql.str_to_key_str(g_series_id) || '_' || g_chart_count;
   g_div_name := g_function_name || '_div';
   g_title := p_title;

   g_div_rows.extend();
   if p_url is not null then 
      g_div_rows(g_div_rows.last).div_text := '<a href="'||p_url||'"><div id="'||g_div_name||'"></div></a>';
   else
      g_div_rows(g_div_rows.last).div_text := '<div id="'||g_div_name||'"></div>';
   end if;
   g_div_rows(g_div_rows.last).div_tags := lower(p_tags);
   g_div_rows(g_div_rows.last).div_group := lower(p_div_group);

   g_callbacks := g_callbacks || arcsql.clob_replace(callback_template, to_clob('#FUNCTION_NAME#'), g_function_name);
   g_vaxis_title := p_vaxis_title;
   g_haxis_title := p_haxis_title;
   g_scale_type := p_scale_type;
   g_line_width := p_line_width;
   g_line_color := p_line_color;
   g_width := p_width;
   g_height := p_height;
   g_background_color := p_background_color;
end;

procedure add_column (
   p_data_type in varchar2,
   p_column_name in varchar2) is 
begin
   arcsql.debug2('add_column');
   assert_series_is_started;
   assert_column_count_is_not_locked;
   g_column_count := g_column_count + 1;
   g_columns := g_columns || 'data.addColumn('''||p_data_type||''', '''||p_column_name||''');
';
end;

procedure add_data (
   p_data in varchar2) is
begin
   arcsql.debug2('add_data: '||p_data);
   assert_series_is_started;
   assert_columns_are_defined;
   assert_chart_is_defined;
   g_row_count := g_row_count + 1;
   g_data := g_data ||
p_data || ',';
end;

procedure end_series is 
begin 
   arcsql.debug2('end_series');
   assert_series_is_started;
   assert_chart_count_is_not_zero;
   if g_chart_in_progress then
      end_chart;
   end if;
   g_charts_js := arcsql.clob_replace(series_template, to_clob('#CALLBACKS#'), g_callbacks);
   g_charts_js := arcsql.clob_replace(g_charts_js, to_clob('#FUNCTIONS#'), g_functions);
   g_series_in_progress := false;
end;

function get_js (
   p_series_id in varchar2) 
   return clob is 
begin
   arcsql.debug2('get_js');
   assert_series_id_has_not_changed(p_series_id);
   if g_series_in_progress then
      end_series;
   end if;
   return g_charts_js;
end;

function get_divs ( -- | Return all or a subset of the divs you need to render the charts.
   p_series_id in varchar2,
   p_div_group in varchar2 default 'default',
   p_having_div_tags in varchar2 default null,
   p_set_class in varchar2 default 'google_charts')
   return clob is 
   i number;
   n number;
begin
   arcsql.debug2('get_divs: p_series_id='||p_series_id||', g_series_id='||g_series_id);
   assert_series_id_has_not_changed(p_series_id);
   g_divs_clob := '<div class="'||p_set_class||'">';
   i := g_div_rows.first;
   arcsql.debug('i='||i);
   while i is not null loop
      n := 0;
      if p_having_div_tags is not null then 
         select count(*) into n from (
            select token from table(to_rows(p_having_div_tags, ','))
            minus 
            select token from table(to_rows(g_div_rows(i).div_tags, ','))
            );
      end if;
      arcsql.debug2('p_div_group='||p_div_group||', g_div_rows(i).div_group='||g_div_rows(i).div_group||', n='||n);
      if p_div_group = g_div_rows(i).div_group and n = 0 then
         g_divs_clob := g_divs_clob || chr(10) || g_div_rows(i).div_text;
      end if;
      i := g_div_rows.next(i);
   end loop;
   g_divs_clob := g_divs_clob || chr(10) || '</div>';
   return g_divs_clob;
end;

end;
/
