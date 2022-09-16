#!/usr/bin/env bash

cp /dev/null ./app_uninstall.sql
grep "^@" app_install.sql | sed 's/^@/\.\//' | \
while read file_name; do 
   echo "grep \"^\-\- uninstall:\" \"${file_name}\""
   grep "^\-\- uninstall:" "${file_name}" | cut -d" " -f3- >> ./app_uninstall.sql
done 




