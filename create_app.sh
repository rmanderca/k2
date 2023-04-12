
function usage {
   cat <<EOF

Creates the files and folders for a new app. To do this a copy is created from the demo app.

./create_app.sh APP_NAME

APP_NAME - Your app name. Will get converted to lower case for folders and file names.

EOF
}

if [[ $# != 1 ]]; then 
   usage 
   exit 0
fi

typeset -l APP_NAME

# set -x

APP_NAME="${1}"
for d in app config install; do
   if [[ ! -d ./${d}/${APP_NAME} ]]; then
      cp -rp ./${d}/demo ./${d}/${APP_NAME}
   fi
done

sed -i "s/app_config/${APP_NAME}_config/g" ./app/${APP_NAME}/dev/app_install.sql
sed -i "s/app_config/${APP_NAME}_config/g" ./app/${APP_NAME}/dev/app_config.sql

mv ./app/${APP_NAME}/dev/demo_install.sql ./app/${APP_NAME}/dev/${APP_NAME}_install.sql
mv ./app/${APP_NAME}/dev/demo_config.sql ./app/${APP_NAME}/dev/${APP_NAME}_config.sql

if [[ -f ./install/${APP_NAME}/dev/demo_install.sql ]]; then
   mv  ./install/${APP_NAME}/dev/demo_install.sql ./install/${APP_NAME}/dev/${APP_NAME}_install.sql 
   sed -i "s/demo/${APP_NAME}/g" ./install/${APP_NAME}/dev/${APP_NAME}_install.sql
   sed -i "s/app_install.sql/${APP_NAME}_install.sql/g" ./install/${APP_NAME}/dev/${APP_NAME}_install.sql
fi


