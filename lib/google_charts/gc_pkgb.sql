create or replace package body gc is 

type table_type is table of varchar2(100) index by binary_integer;
g_divs_array table_type;
g_divs clob;

g_series_id varchar2(100);

g_chunk_pos number := 1;
g_chunk_amount number := 20000;

-- Reset for each new series.
g_charts_js clob;
g_chart_count number := 0;

g_functions clob;
g_charts clob;
g_callbacks clob;
g_series_in_progress boolean := false;

-- Most reset for each new chart.
g_function varchar2(4000);
g_function_name varchar2(200);
g_columns varchar2(2000);
g_column_count number := 0;
g_lock_column_count boolean := false;
g_data clob;
g_row_count number := 0;
g_options clob;
g_div_name clob;
g_title varchar2(200);
g_width number := 600;
g_height number := 400;
g_chart_in_progress boolean := false;
g_vaxis_title varchar2(200) := '';
g_haxis_title varchar2(200) := '';
g_scale_type varchar2(200);
g_line_width number default 1;
g_line_color varchar2(200);
g_background_color varchar2(200);

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
      raise_application_error(-20001, 'Chart does not have any date points!');
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

procedure init_series_defaults is 
begin 
   arcsql.debug2('init_series_defaults');
   g_series_id := null;
   g_charts_js := null;
   g_chart_count := 0;
   g_divs_array.delete;
   g_divs := null;
   g_functions := null;
   g_charts := null;
   g_callbacks := null;
   g_columns := null;
   g_series_in_progress := false;
   g_lock_column_count := false;
   init_chart_defaults;
end;

-- Everything above this line is private.

procedure start_series (
   p_series_id in varchar2) is 
begin
   arcsql.debug2('start_series');
   init_series_defaults;
   g_series_id := p_series_id;
   g_series_in_progress := true;
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
   p_div_group in number default 0) is 
begin
   arcsql.debug2('add_line_chart: ' || p_title);
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
   -- Tags and group are added as a comment which can be searched when get_divs is called.
   g_divs_array(g_chart_count) := '<div id="'||g_div_name||'"><!-- tags=['||lower(p_tags)||'], group='||p_div_group||' --></div>
';
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


function get_js_chunk return varchar2 is 
   chunk clob;
begin
   arcsql.debug2('get_js_chunk');
   dbms_lob.read(g_charts_js, g_chunk_amount, g_chunk_pos, chunk);
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
   return g_charts_js;
end;

function get_divs (
   p_series_id in varchar2,
   p_div_group in number default null,
   p_set_class in varchar2 default 'gc',
   p_having_tags in varchar2 default null) return clob is 
   g_div_index number;
   add_div boolean default false;
   start_of_tags number;
   end_of_tags number;
   tags_list varchar2(100) default null;
   n number;
begin
   arcsql.debug2('get_divs: '||p_series_id);
   assert_series_id_has_not_changed(p_series_id);
   if g_series_in_progress then
      end_series;
   end if;
   g_div_index := g_divs_array.first;
   while g_div_index is not null loop 
      add_div := true;

      if p_div_group is not null then 
         if not instr(g_divs_array(g_div_index), 'group='||p_div_group) > 0 then 
            add_div := false;
         end if;
      end if;

      if p_having_tags is not null then 
         -- Get the list of tags from the div
         start_of_tags := instr(g_divs_array(g_div_index), 'tags=[')+6;
         end_of_tags := instr(g_divs_array(g_div_index), ']', start_of_tags);
         tags_list := substr(g_divs_array(g_div_index), start_of_tags, end_of_tags-start_of_tags);

         select count(*) into n from (
         select trim(regexp_substr(p_having_tags,'[^,]+', 1, level)) col1 from dual
                connect by level <= regexp_count(p_having_tags, ',') + 1
         minus
         select trim(regexp_substr(tags_list,'[^,]+', 1, level)) col1 from dual
                connect by level <= regexp_count(tags_list, ',') + 1);
         if n > 0 then 
            add_div := false;
         end if;
      end if;

      if add_div then
            g_divs := g_divs || '   ' ||g_divs_array(g_div_index);
      end if;

      g_div_index := g_divs_array.next(g_div_index);
   end loop;
   return '
<div class="'||p_set_class||'">
'||g_divs||'</div>';
end;

end;
/
