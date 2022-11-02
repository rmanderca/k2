create or replace package body gc is 

g_series_id varchar2(100);

g_chunk_pos number := 1;
g_chunk_amount number := 20000;

-- Reset for each new series.
g_js clob;
g_chart_count number := 0;
g_divs clob;
g_functions clob;
g_charts clob;
g_callbacks clob;
g_series_in_progress boolean := false;

-- Most reset for each new chart.
g_function clob;
g_function_name clob;
g_columns clob;
g_column_count number := 0;
g_lock_column_count boolean := false;
g_data clob;
g_row_count number := 0;
g_options clob;
g_div_name clob;
g_title clob;
g_width number;
g_height number;
g_div clob;
g_chart_in_progress boolean := false;
g_vaxis_title varchar2(100) := '';
g_haxis_title varchar2(100) := '';
g_scale_type varchar2(100) := 'linear';
g_line_width number default 1;
g_line_color varchar2(100) := 'black';

procedure raise_column_count_is_locked is
begin
   if g_lock_column_count then
      raise_application_error(-20001, 'Column count is locked.');
   end if;
end;

procedure raise_series_not_in_progress is 
begin 
   if not g_series_in_progress then 
      raise_application_error(-20001, 'Google Chart series not in progress!');
   end if;
end;

procedure raise_chart_not_in_progress is 
begin
   if not g_chart_in_progress then 
      raise_application_error(-20002, 'Google Chart not in progress!');
   end if;
end;

procedure raise_column_count_is_zero is 
begin
   if g_column_count = 0 then 
      raise_application_error(-20001, 'Column count is zero!');
   end if;
end;

procedure raise_row_count_is_zero is 
begin
   if g_row_count = 0 then 
      raise_application_error(-20001, 'Row count is zero!');
   end if;
end;

procedure raise_row_count_is_not_zero is 
begin
   if g_row_count <> 0 then 
      raise_application_error(-20001, 'Row count is not zero!');
   end if;
end;

procedure raise_chart_count_is_not_zero is 
begin
   if g_chart_count <> 0 then 
      raise_application_error(-20001, 'Chart count is not zero!');
   end if;
end;

function series_template return varchar2 is
begin
   return '
   <script src="https://www.gstatic.com/charts/loader.js"></script>
   <script>
   console.log("Loading Google Charts...");
   google.charts.load(''current'', {''packages'':[''corechart'']});
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

procedure init_chart is 
begin
   arcsql.debug2('init_chart');
   g_function := null;
   g_function_name := null;
   g_data := null;
   g_options := null;
   g_div_name := null;
   g_title := null;
   g_width := 600;
   g_height := 400;
   g_div := null;
   g_row_count := 0;
   g_chart_in_progress := true;
   g_vaxis_title := '';
   g_haxis_title := '';
   g_scale_type := 'linear';
   g_line_width := 1;
   g_line_color := 'black';
end;

-- Everything above this line is private.

procedure start_series (
   p_series_id in varchar2) is 
begin
   arcsql.debug2('start_series');
   g_series_id := p_series_id;
   g_js := null;
   g_divs := null;
   g_functions := null;
   g_chart_count := 0;
   g_callbacks := null;
   g_series_in_progress := true;
   g_lock_column_count := false;
   g_columns := null;
end;

procedure add_chart ( -- | Start creating a new chart.
   p_title in varchar2,
   p_vaxis_title in varchar2 default '',
   p_haxis_title in varchar2 default '',
   p_scale_type in varchar2 default 'linear',
   p_line_width in number default 1,
   p_line_color in varchar2 default 'black') is 
begin
   arcsql.debug2('add_chart: ' || p_title);
   raise_series_not_in_progress;
   -- Columns must be defined before adding charts.
   raise_column_count_is_zero;
   if g_chart_in_progress then
      end_chart;
   end if;
   init_chart;
   g_chart_in_progress := true;
   g_lock_column_count := true;
   g_chart_count := g_chart_count + 1;
   g_function_name := arcsql.str_to_key_str(g_series_id) || '_' || g_chart_count;
   g_div_name := g_function_name || '_div';
   g_title := p_title;
   g_divs := g_divs ||'<div id="'||g_div_name||'"></div>
';
   g_callbacks := g_callbacks || arcsql.clob_replace(callback_template, to_clob('#FUNCTION_NAME#'), g_function_name);
   g_vaxis_title := p_vaxis_title;
   g_haxis_title := p_haxis_title;
   g_scale_type := p_scale_type;
   g_line_width := p_line_width;
   g_line_color := p_line_color;
end;

procedure add_column (
   p_data_type in varchar2,
   p_column_name in varchar2) is 
begin
   arcsql.debug2('add_column');
   raise_series_not_in_progress;
   raise_column_count_is_locked;
   g_column_count := g_column_count + 1;
   g_columns := g_columns || 'data.addColumn('''||p_data_type||''', '''||p_column_name||''');
';
end;

procedure add_data (
   p_data in varchar2) is
begin
   arcsql.debug2('add_data: '||p_data);
   raise_series_not_in_progress;
   raise_column_count_is_zero;
   raise_chart_not_in_progress;
   g_row_count := g_row_count + 1;
   g_data := g_data ||
p_data || ',';
end;

procedure end_chart is 
begin 
   arcsql.debug2('end_chart');
   raise_series_not_in_progress;
   raise_chart_not_in_progress;
   raise_column_count_is_zero;
   raise_row_count_is_zero;
   g_function := arcsql.clob_replace(function_template, to_clob('#FUNCTION_NAME#'), g_function_name);
   g_function := arcsql.clob_replace(g_function, to_clob('#DIV_NAME#'), g_div_name);
   g_function := arcsql.clob_replace(g_function, to_clob('#COLUMNS#'), g_columns);
   g_function := arcsql.clob_replace(g_function, to_clob('#DATA#'), rtrim(g_data, ','));
   g_function := arcsql.clob_replace(g_function, to_clob('#TITLE#'), g_title);
   g_function := arcsql.clob_replace(g_function, to_clob('#WIDTH#'), to_clob(g_width));
   g_function := arcsql.clob_replace(g_function, to_clob('#HEIGHT#'), to_clob(g_height));
   g_function := arcsql.clob_replace(g_function, to_clob('#VAXIS_TITLE#'), to_clob(g_vaxis_title));
   g_function := arcsql.clob_replace(g_function, to_clob('#HAXIS_TITLE#'), to_clob(g_haxis_title));
   g_function := arcsql.clob_replace(g_function, to_clob('#SCALE_TYPE#'), to_clob(g_scale_type));
   g_function := arcsql.clob_replace(g_function, to_clob('#LINE_WIDTH#'), to_clob(g_line_width));
   g_function := arcsql.clob_replace(g_function, to_clob('#LINE_COLOR#'), to_clob(g_line_color));
   g_functions := g_functions || g_function;
   g_chart_in_progress := false;
end;

procedure end_series is 
begin 
   arcsql.debug2('end_series');
   raise_series_not_in_progress;
   raise_column_count_is_zero;
   raise_row_count_is_zero;
   if g_chart_in_progress then
      end_chart;
   end if;
   g_js := arcsql.clob_replace(series_template, to_clob('#CALLBACKS#'), g_callbacks);
   g_js := arcsql.clob_replace(g_js, to_clob('#FUNCTIONS#'), g_functions);
   g_js := arcsql.clob_replace(g_js, to_clob('#DIVS#'), g_divs);
   g_series_in_progress := false;
end;


function get_js_chunk return varchar2 is 
   chunk clob;
begin
   arcsql.debug2('get_js_chunk');
   dbms_lob.read(g_js, g_chunk_amount, g_chunk_pos, chunk);
   g_chunk_pos := g_chunk_pos + g_chunk_amount;
   -- arcsql.debug2('chunk: '||chunk);
   return chunk;
exception
   when no_data_found then 
      g_chunk_pos := 1;
      g_chunk_amount := 20000;
      return null;
end;

function get_js return clob is 
begin
   arcsql.debug2('get_js');
   if g_series_in_progress then
      end_series;
   end if;
   return g_js;
end;

function get_divs return clob is 
begin
   arcsql.debug2('get_divs');
   if g_series_in_progress then
      end_series;
   end if;
   return g_divs;
end;

end;
/
