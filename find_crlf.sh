#!/usr/bin/env bash

# Finds and removes ^M characters from files.
# >>> find_crlf.sh [-fix] [DIRECTORY]

# https://github.com/ethanpost/shell_scripts

FIX=0

while (( $# > 0 )); do
   case "${1}" in
      "--fix"|"-fix") FIX=1 ;;
      *) break ;;
   esac
   shift
done

function find_non_binary_files {
   find "${1}" -type f -exec grep -Iq . {} \; -print
}

function remove_cr_from_file {
   cat "${1}" | tr -d '\015' > "${1}~"
   mv "${1}~" "${1}"
}

START_DIR="${1:-.}"
SAY="Removing carriage returns (^M) from the following files..."
while read FILE; do
   if grep $'\r' "${FILE}" 1> /dev/null; then
      if (( ${FIX} )); then 
         [[ -n "${SAY}" ]] && echo "${SAY}" && SAY=
         remove_cr_from_file "${FILE}"
      fi
      echo "${FILE}"
   fi 
done < <(find_non_binary_files "${START_DIR}" | egrep -v "git")

exit 0
