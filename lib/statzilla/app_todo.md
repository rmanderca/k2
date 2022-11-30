
## Implement stat profiles which automatically apply a set of rules to a group of stats.
   - Ideally statzilla could recognize a stat group and prompt to apply a profile via UI or email.

## Should track metrics for stat groups
	- How many are elevated
	- How many key metrics are elevated/depressed
	- What is distribution of high to normal to low?
	- Do above by metrics class.

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



