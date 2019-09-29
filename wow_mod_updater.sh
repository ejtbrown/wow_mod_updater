#!/bin/bash
# World of Warcraft Mod Updater for Linux

#### Runtime Variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
TIMESTAMP=$(date +%F--%R)

source "${SCRIPT_DIR}/wow_mod_updater.rc"

#### Announce the run. Note that the first pipe to log file
# is a non-append; this is what causes the log file to be
# recreated each time its run
echo "Starting run at timestamp ${TIMESTAMP}" > ${LOG_FILE}
echo "::Updating Mods::" | tee -a "${LOG_FILE}"
echo " -- CHROMIUM_EXECUTABLE: ${CHROMIUM_EXECUTABLE}" | tee -a "${LOG_FILE}"
echo " -- CHROMIUM_LOG:        ${CHROMIUM_LOG}" | tee -a "${LOG_FILE}"
echo " -- TEMP_STORAGE:        ${TEMP_STORAGE}" | tee -a "${LOG_FILE}"
echo " -- TEMP_ADDONS:         ${TEMP_ADDONS}" | tee -a "${LOG_FILE}"
echo " -- ERROR_FILE:          ${ERROR_FILE}" | tee -a "${LOG_FILE}"
echo " -- NOTIFY_SEND_LEVEL:   ${NOTIFY_SEND_LEVEL}" | tee -a "${LOG_FILE}"
echo " -- MOD_DIR:             ${MOD_DIR}" | tee -a "${LOG_FILE}"
echo " -- MOD_LIST:            ${MOD_LIST}" | tee -a "${LOG_FILE}"
echo " -- FRESHEN:             ${FRESHEN}" | tee -a "${LOG_FILE}"
echo " -- PROTECTED_REGEX:     ${PROTECTED_REGEX}" | tee -a "${LOG_FILE}"
echo " -- TIMESTAMP:           ${TIMESTAMP}" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"

#### Ensure that we're working in the temporary storage path
rm -rf "${TEMP_STORAGE}" &>> "${LOG_FILE}"
mkdir -p "${TEMP_ADDONS}" &>> "${LOG_FILE}"
cd "${TEMP_STORAGE}" &>> "${LOG_FILE}"
touch "${ERROR_FILE}"

#### Run selenium-downloader.py to download the zip files
echo "##### Downloading Latest Versions #####"
${SCRIPT_DIR}/selenium-downloader.py | tee "${CHROMIUM_LOG}"
cat "${CHROMIUM_LOG}" >> "${LOG_FILE}"
grep -e "^ERROR" "${CHROMIUM_LOG}" >> "${ERROR_FILE}"
echo "" | tee -a "${LOG_FILE}"

echo "##### Unzipping Files #####"
cd "${TEMP_STORAGE}" &>> "${LOG_FILE}"
for f in *.zip; do
  unzip -od "${TEMP_ADDONS}" "${f}" &>> "${LOG_FILE}"
  if [[ "$?" != "0" ]]; then
    echo "ERROR: ${f} unzip failed" | tee -a "${LOG_FILE}"
    echo "${f} unzip failed" >> "${ERROR_FILE}"
  fi
  chmod -R u+w "${TEMP_STORAGE}"
done

#### If we're freshening, we'll clear out the MOD_DIR,
#### except for things that match the PROTECTED_REGEX
#### before we start populating
if [[ "${FRESHEN}" == "1" ]]; then
  echo "##### Clearing Out AddOns #####"
  cd "${MOD_DIR}" &>> "${LOG_FILE}"
  for check_file in ./*; do
    if [[ "$(basename '${check_file}')" =~ $PROTECTED_REGEX ]]; then
      echo "Skipping $(basename '${check_file}') since it matches PROTECTED_REGEX" | tee -a "${LOG_FILE}"
    else
      mv "${check_file}" "${MOD-DIR}/${TIMESTAMP}-$(basename '${check_file}')" &>> "${LOG_FILE}"
    fi
  done
  echo "" | tee -a "${LOG_FILE}"
fi

#### Check the directories that were unzipped; this
#### is where we populate the MOD_DIR with what we
#### downloaded
echo "##### Checking Downloaded AddOns for Updates #####"
mkdir -p "${MOD_DIR}-old" &>> "${LOG_FILE}"
for check_file in $(ls "${TEMP_ADDONS}"); do
  # Create an MD5 hash of all of the files / file names in the
  # existing addon. We'll use this later to see if we need to
  # update the addon
  if [[ -d "${MOD_DIR}/${check_file}" ]]; then
    EXISTING_MD5=$(find "${MOD_DIR}/${check_file}" -type f -exec md5sum '{}' \; | awk -F'/' '{print $1 $NF}' | md5sum | awk '{print $1}')
  else
    EXISTING_MD5="<no-existing>"
  fi

  # Create an MD5 hash of all of the files / file names in the
  # newly downloaded addon. We'll compare this to the MD5 hash
  # that we took of the existing one to determine if we need to
  # update the addons
  TEMP_MD5=$(find "${TEMP_ADDONS}/${check_file}" -type f -exec md5sum '{}' \; | awk -F'/' '{print $1 $NF}' | md5sum | awk '{print $1}')

  echo "${check_file}: ${EXISTING_MD5} old, ${TEMP_MD5} new" >> "${LOG_FILE}"

  # Check to see if we need to update the addon
  if [[ "${TEMP_MD5}" != "${EXISTING_MD5}" ]]; then
    if [[ "${EXISTING_MD5}" == "<no-existing>" ]]; then
      # If the hash is '<no-existing>', that means that the
      # directory doesn't exist (this was checked a few
      # lines ago). We'll
      echo "Adding ${check_file}" | tee -a "${LOG_FILE}"
    else
      echo "Updating ${check_file}" | tee -a "${LOG_FILE}"
    fi

    # Move the existing AddOn into the '-old' directory,
    # and copy the new addons into the mods directory
    mv "${MOD_DIR}/${check_file}" "${MOD_DIR}-old/${TIMESTAMP}-${check_file}" &>> "${LOG_FILE}"
    cp -r "${TEMP_ADDONS}/${check_file}" "${MOD_DIR}/${check_file}" &>> "${LOG_FILE}"
  else
    echo "Already up-to-date: ${check_file}" | tee -a "${LOG_FILE}"
  fi

  # Clean up the AddOn that we downloaded
  rm -rf "${TEMP_ADDONS}/${check_file}"
done
echo "" | tee -a "${LOG_FILE}"

# Generate a summary
ADDED=$(grep -i "^Adding" "${LOG_FILE}" | wc -l)
UPDATED=$(grep -i "^Updating" "${LOG_FILE}" | wc -l)
ALREADY=$(grep -i "^Already" "${LOG_FILE}" | wc -l)
ERROR_COUNT=$(cat "${ERROR_FILE}" | wc -l)

# Send desktop notifications, if enabled
if [[ "${NOTIFY_SEND_LEVEL}" == "1" ]]; then
  # NOTIFY_SEND_LEVEL 1 means erros only, so we'll check to see
  # if there are any errors, and send them if there are
  if [[ "${ERROR_COUNT}" != "0" ]]; then
    eval "export $(egrep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u ${LOGNAME} ${NOTIFY_SEND_PROC})/environ | tr '\0' '\n')"
    notify-send "WoW Mod Updater" "$(cat ${ERROR_FILE})"
  fi

elif [[ "${NOTIFY_SEND_LEVEL}" == "2" ]]; then
  # NOTIFY_SEND_LEVEL 2 means send a summary of the run. To do
  # this, we'll need to build up a summary
  eval "export $(egrep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u ${LOGNAME} ${NOTIFY_SEND_PROC})/environ | tr '\0' '\n')"
  notify-send "WoW Mod Updater" "${ADDED} mods added\n${UPDATED} mods updated\n${ALREADY} mods already up-to-date\n${ERROR_COUNT} errors encountered"
fi

echo "" | tee -a "${LOG_FILE}"
echo "Run Summary:" | tee -a "${LOG_FILE}"
echo "-- Already Up-To-Date: ${ALREADY} mods" | tee -a "${LOG_FILE}"
echo "-- Updated           : ${UPDATED} mods" | tee -a "${LOG_FILE}"
echo "-- Added / New       : ${ADDED} mods" | tee -a "${LOG_FILE}"
echo "-- Errors:           : ${ERROR_COUNT}" | tee -a "${LOG_FILE}"
