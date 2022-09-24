create or replace view accounts_of_interest as (
select 'Recent Locked/Expired' reason,
       username,
       account_status,
       lock_date,
       expiry_date,
       created
  from dba_users 
 where -- Accounts that have been locked or expired in the last 10 days.
       (account_status != 'OPEN' and (nvl(lock_date, sysdate-999) > trunc(sysdate)-10 or nvl(expiry_date, sysdate-999) > trunc(sysdate)-10))
union all
select 'Expiring',
       username,
       account_status,
       lock_date,
       expiry_date,
       created
  from dba_users 
 where -- Accounts which will expire in the next 10 days.
       (account_status = 'OPEN' and nvl(expiry_date, sysdate+999) <= trunc(sysdate)+30)
union all
select 'New',
       username,
       account_status,
       lock_date,
       expiry_date,
       created
  from dba_users 
 where -- Accounts created within the last 10 days.
       (created >= trunc(sysdate)-30));