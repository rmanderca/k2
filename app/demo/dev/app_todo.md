## Need to do the UTC timezone thing.

## Add internal metrics

Track total time and size of various buckets and total size of statzilla.

## Auto clean up

Add bucket properties to automatically remove stale/dead records from the stat* tables.
- These are records that are not being updated.

## Add various scoring mechanisms.

## Add event timing

## Parse display name from stat_name/id and figure out how to handle tags in {}.

## Not happy about start_event in ARCSQL, all wrong, must replace!

## Track state in schema someplace so we can detect when app has been refreshed/replaced and trigger an event hook like on_create_user but on_app_refresh.




