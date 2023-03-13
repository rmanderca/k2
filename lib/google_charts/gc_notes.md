
## Series

A series represents all of the charts available.

Ideally everything is done within a single call since we are using a lot of globals.

If you make more than one call we check to see if the series_id matches what you provide.
If it does not we know something has gone wrong and we will throw an error.

series_id is a string value

## <div> groups and tags

When you create a chart you can add a div_group and div_tags.

You can then render your divs in the UI and filter by group or tag.

This allows you to place different sets of charts in different locations in your UI.

Tags can be used by the user or can be used to dynamically tag a chart.

For example a metric which is suspicious could be tagged "important".

You could then render charts tagged "important" at the top of the screen.

## ToDo maybe

* Consider implementing/reviewing if needed: https://blog.cloudnueva.com/apex-plsql-dynamic-content-regions-and-the-ppr-challenge
* Save generated charts
* Send via email
* Ability to easily style, more chart types.

