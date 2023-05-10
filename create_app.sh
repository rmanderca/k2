
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

function random_string {
   local length=$1
   local r=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w $length | head -n 1)
   echo "$r"
}

function random_word {
    list_random_words | grep "^[[:lower:]]\{8,\}$" | shuf -n 10 | tail -1 | awk '{print toupper(substr($0, 1, 1)) substr($0, 2)}' 
}

function list_random_words {
cat <<EOF
carriage
baseball
invasion
reliance
disagree
material
freshman
feedback
sickness
reporter
detector
dominant
rhetoric
recovery
cemetery
surprise
conflict
momentum
conceive
customer
location
minority
hospital
producer
diplomat
fraction
traction
register
consider
abstract
confront
fantasy2
ancestor
sunshine
umbrella
training
rotation
perceive
cylinder
observer
priority
scramble
dialogue
mistreat
explicit
diameter
business
flourish
creation
finished
EOF
}

set -x

APP_NAME="${1}"

# Copy the 3 directories from demo to the new app name.
for d in app config install; do
   if [[ ! -d ./${d}/${APP_NAME} ]]; then
      cp -rp ./${d}/demo ./${d}/${APP_NAME}
   fi
done

# Find all instances of demo_config in demo_install.sql and change to app name config.
sed -i "s/demo_config/${APP_NAME}_config/g" ./app/${APP_NAME}/dev/demo_install.sql
# Do the same in demo_config.sql.
sed -i "s/demo_config/${APP_NAME}_config/g" ./app/${APP_NAME}/dev/demo_config.sql

sed -i "s/DEMO/${APP_NAME}/g" ./config/${APP_NAME}/dev/secret_app_config.sql
app_test_pass="$(random_word)$(random_string 3)!"
sed -i "s/APP_TEST_PASS/${app_test_pass}/g" ./config/${APP_NAME}/dev/secret_app_config.sql

secret_key=$(random_string 64)
sed -i "s/SECRET_KEY/${secret_key}/g" ./config/${APP_NAME}/dev/secret_k2_config.sql

secret_key=$(random_string 64)
sed -i "s/SAAS_AUTH_SALT/${secret_key}/g" ./config/${APP_NAME}/dev/secret_saas_auth_config.sql

mv ./app/${APP_NAME}/dev/demo_install.sql ./app/${APP_NAME}/dev/${APP_NAME}_install.sql
mv ./app/${APP_NAME}/dev/demo_config.sql ./app/${APP_NAME}/dev/${APP_NAME}_config.sql

if [[ -f ./install/${APP_NAME}/dev/demo_install.sql ]]; then
   mv  ./install/${APP_NAME}/dev/demo_install.sql ./install/${APP_NAME}/dev/${APP_NAME}_install.sql 
   sed -i "s/demo/${APP_NAME}/g" ./install/${APP_NAME}/dev/${APP_NAME}_install.sql
   sed -i "s/app_install.sql/${APP_NAME}_install.sql/g" ./install/${APP_NAME}/dev/${APP_NAME}_install.sql
fi


