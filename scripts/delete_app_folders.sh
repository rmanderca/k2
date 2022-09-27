# -- | Deletes the folders associated with an application.

function usage {
	cat <<EOF

./delete_app_folders.sh APP_NAME

APP_NAME - Your app name. Will get converted to lower case to match folder name.

EOF
}

if [[ $# != 1 ]]; then 
	usage 
	exit 0
fi

typeset -l APP_NAME


APP_NAME="${1:-NOTHING}"
for d in app config install test; do
    # Might be run from root dir or current dir, test for both.
	if [[ -d ./${d}/${APP_NAME} ]]; then
		rm -rf ./${d}/${APP_NAME}
	elif [[ -d ../${d}/${APP_NAME} ]]; then
		rm -rf ../${d}/${APP_NAME}
	fi
done


