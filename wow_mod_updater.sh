#!/bin/bash
# World of Warcraft Mod Updater for Linux

#### Configuration Variables
# TEMP_STORAGE is the directory to use for temporary storage
# of downloaded files
TEMP_STORAGE="/tmp/wow-mods"

# TEMP_ADDONS is the directory into which the downloaded addons
# are to be unzipped. NOTE: this is *still* a temporary
# directory, because this is the place from which the script
# checks against the installed AddOns to see which ones are
# in need of update
TEMP_ADDONS="${TEMP_STORAGE}/AddOns"

# ERROR_FILE is the name of the file that will accumulate text
# describing any errors that are encountered. This is used to
# summarize, as well as for desktop notifications (if enabled)
ERROR_FILE="${TEMP_STORAGE}/errors"

# NOTIFY_SEND_LEVEL can be set to 0 (disabled), 1 (errors) or
# 2 (full summary). If set to 0, the notify-send command will
# not be used at all (chose this if desktop notifications are
# not desired, or if the system does not have notify-send).
# If set to 1, desktop notifications will only be sent if
# errors are encountered during the run. If set to 2, a summary
# of the run will be sent at completion
NOTIFY_SEND_LEVEL=2

# MOD_DIR is the place where the AddOns are installed; the
# place that the game will look for the addons
MOD_DIR="${HOME}/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns"

# MOD_LIST contains the path and file name of the file
# containing all of the mods to be downloaded. The format
# of this file is:
#   a) One mod per line (order does not matter)
#   b) Each line contains two fields, separated by a space
#   c) The first field contains the name of the source
#   d) The second field contains the name of the mod
# Valid Sources:
#   - curse_forge
#   - wow_ace
# Examples:
#   curse_forge deadly-boss-mods
#   wow_ace recount
# Note on Mod Name:
#   The mod name (for the purpose of this file) appears in
#   the URL when viewed on the website where it's hosted. 
#   In most cases, it's the common name of the mod, with
#   dashes in place of the spaces, in lowercase letters
#   (e.g. "Deadly Boss Mods" is "deadly-boss-mods")
MOD_LIST="${HOME}/wow_mod_updater/wow_mods"

# LOG_FILE contains the path and file name of the file to
# which the detailed log data should be saved. The various
# commands which constitute this script will have their
# stdout and stderr directed into this file. NOTE: this
# file will be overwritten each time the script is run!
LOG_FILE="${HOME}/wow_mod_updater/wow_mod_updater.log"

# FRESHEN controls the behavior of the script; if it's set
# to 1, this will cause the script to clear out the contents
# of the MOD_DIR before populating with the stuff that was
# downloaded. This will make it so that the *ONLY* contents
# of the MOD_DIR will be what was downloaded (or what matched
# PROTECTED_REGEX)
FRESHEN="0"

# PROTECTED_REGEX is used *ONLY* when FRESHEN is set to 1.
# Any directory name (basename only - NOT the full path)
# that matches the PROTECTED_REGEX will not be deleted
# during the freshen process
PROTECTED_REGEX="^Blizzard_"

#### Runtime Variables
TIMESTAMP=$(date +%F--%R)

#### parse_url function; surprisingly, for parsing URLs
# Kind thanks to the author and stackexchange:
# https://stackoverflow.com/questions/6174220/parse-url-in-shell-script
parse_url() {
    local query1 query2 path1 path2

    # extract the protocol
    proto="$(echo $1 | grep :// | sed -e's,^\(.*://\).*,\1,g')"

    if [[ ! -z $proto ]] ; then
            # remove the protocol
            url="$(echo ${1/$proto/})"

            # extract the user (if any)
            login="$(echo $url | grep @ | cut -d@ -f1)"

            # extract the host
            host="$(echo ${url/$login@/} | cut -d/ -f1)"

            # by request - try to extract the port
            port="$(echo $host | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"

            # extract the uri (if any)
            resource="/$(echo $url | grep / | cut -d/ -f2-)"
    else
            url=""
            login=""
            host=""
            port=""
            resource=$1
    fi

    # extract the path (if any)
    path1="$(echo $resource | grep ? | cut -d? -f1 )"
    path2="$(echo $resource | grep \# | cut -d# -f1 )"
    path=$path1
    if [[ -z $path ]] ; then path=$path2 ; fi
    if [[ -z $path ]] ; then path=$resource ; fi

    # extract the query (if any)
    query1="$(echo $resource | grep ? | cut -d? -f2-)"
    query2="$(echo $query1 | grep \# | cut -d\# -f1 )"
    query=$query2
    if [[ -z $query ]] ; then query=$query1 ; fi

    # extract the fragment (if any)
    fragment="$(echo $resource | grep \# | cut -d\# -f2 )"
}

#### do_unzip: Unzip a file. This is embodied in a function
# to address the possibilty of sources that use something
# other than zip format
do_unzip() {
    unzip -od "${TEMP_ADDONS}" "${1}" &>> "${LOG_FILE}"
    if [[ "$?" != "0" ]]; then
      echo "ERROR: ${mod} unzip failed" | tee -a "${LOG_FILE}"
      echo "${mod} unzip failed" >> "${ERROR_FILE}"
    fi
    chmod -R 755 "${TEMP_ADDONS}"
    rm -f "${1}"
}

#### Curse Forge Handler: deals with mod downloads from 
# curse forge
curse_forge() {
    local final rel
    
    echo "Downloading ${1} from Curse Forge (${OUTFILE})"  | tee -a "${LOG_FILE}"
    
    # Curse Forge uses a JavaScript download redirect page;
    # it sends the uses JavaScript to kick off the download.
    # What we do is scrape this page for the "If the DL didn't
    # start, click here" link, then pulls the zip file from
    # there
    wget "https://www.curseforge.com/wow/addons/${1}/download" --output-document "${OUTFILE}.html" &>> "${LOG_FILE}"
    if [[ "${?}" != "0" ]]; then
        echo "ERROR: Reference download of ${1} failed"  | tee -a "${LOG_FILE}"
        echo "Reference download of ${1} failed" >> "${ERROR_FILE}"
        return
    fi
    
    # Scrape out the *real* download link
    rel=$(grep -i ">here</a>" ${OUTFILE}.html | awk 'BEGIN{
        RS="</a>"
        IGNORECASE=1
        }
        {
          for(o=1;o<=NF;o++){
            if ( $o ~ /href/){
              gsub(/.*href=\042/,"",$o)
              gsub(/\042.*/,"",$o)
              print $(o)
            }
          }
        }')
    parse_url "${rel}"
    
    # Build up the final URL
    final=$(echo "https://www.curseforge.com${resource}")
    echo "Using URL ${final} saving to ${OUTFILE}" >> "${LOG_FILE}"
    
    # Then download from that URL
    wget "${final}" --output-document "${OUTFILE}" &>> "${LOG_FILE}"    
    if [[ "${?}" != "0" ]]; then
        echo "ERROR: Final download of ${1} failed"  | tee -a "${LOG_FILE}"
        echo "Final download of ${1} failed" >> "${ERROR_FILE}"
        return
    fi
    
    # And finally, unzip the file
    do_unzip ${OUTFILE}
}

#### WoW Ace Handler: deals with mod downloads from WoW Ace
wow_ace() {
    # WoW Ace allows for direct download, so we can just
    # go for it
    echo "Downloading ${1} from WoW Ace (${OUTFILE})"  | tee -a "${LOG_FILE}"
    
    URL=$(echo "https://www.wowace.com/projects/${1}/files/latest")
    echo "Using URL ${URL} saving to ${OUTFILE}" >> "${LOG_FILE}"    
    wget "${URL}" --output-document "${OUTFILE}" &>> "${LOG_FILE}"
    if [[ "${?}" != "0" ]]; then
        echo "ERROR: Final download of ${1} failed"  | tee -a "${LOG_FILE}"
        echo "Final download of ${1} failed" >> "${ERROR_FILE}"
        return
    fi
    
    do_unzip ${OUTFILE}
}

#### Announce the run. Note that the first pipe to log file
# is a non-append; this is what causes the log file to be
# recreated each time its run
echo "Starting run at timestamp ${TIMESTAMP}" > ${LOG_FILE}
echo "::Updating Mods::" | tee -a "${LOG_FILE}"
echo " -- TEMP_STORAGE:      ${TEMP_STORAGE}" | tee -a "${LOG_FILE}"
echo " -- TEMP_ADDONS:       ${TEMP_ADDONS}" | tee -a "${LOG_FILE}"
echo " -- ERROR_FILE:        ${ERROR_FILE}" | tee -a "${LOG_FILE}"
echo " -- NOTIFY_SEND_LEVEL: ${NOTIFY_SEND_LEVEL}" | tee -a "${LOG_FILE}"
echo " -- MOD_DIR:           ${MOD_DIR}" | tee -a "${LOG_FILE}"
echo " -- MOD_LIST:          ${MOD_LIST}" | tee -a "${LOG_FILE}"
echo " -- FRESHEN:           ${FRESHEN}" | tee -a "${LOG_FILE}"
echo " -- PROTECTED_REGEX:   ${PROTECTED_REGEX}" | tee -a "${LOG_FILE}"
echo " -- TIMESTAMP:         ${TIMESTAMP}" | tee -a "${LOG_FILE}"
echo "" | tee -a "${LOG_FILE}"

#### Ensure that we're working in the temporary storage path
rm -rf "${TEMP_STORAGE}" &>> "${LOG_FILE}"
mkdir -p "${TEMP_ADDONS}" &>> "${LOG_FILE}"
cd "${TEMP_STORAGE}" &>> "${LOG_FILE}"
touch "${ERROR_FILE}"

#### Walk the mod list, downloading the files
echo "##### Downloading Latest Versions #####"
while read mod; do
  # In order to avoid name colisions, we'll download to a file
  # named after the MD5 hash of the URL. This *should* make it
  # impossible to step on an existing file
  OUTFILE=$(echo "${mod}" | md5sum | awk '{print $1}')
  
  # Make sure that we're not dealing with a blank line
  LINE_LEN=$(echo "${mod}" | tr -d '[:space:]' | wc -c)
  if [[ "${LINE_LEN}" != "0" ]]; then
    # Pick apart the line
    MOD_SRC=$(echo "${mod}" | awk '{print $1}')
    MOD_NAME=$(echo "${mod}" | awk '{print $2}')

    case $MOD_SRC in
      curse_forge)
        curse_forge "${MOD_NAME}"
        ;;
      wow_ace)
        wow_ace "${MOD_NAME}"
        ;;    
      *)
        echo "Unknown mod source '${MOD_SRC}'" | tee -a "${LOG_FILE}" | tee -a "${ERROR_FILE}"
        ;;
    esac
  fi
done <"${MOD_LIST}"
echo "" | tee -a "${LOG_FILE}"

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

# Send desktop notifications, if enabled
if [[ "${NOTIFY_SEND_LEVEL}" == "1" ]]; then
  # NOTIFY_SEND_LEVEL 1 means erros only, so we'll check to see
  # if there are any errors, and send them if there are  
  ERROR_COUNT=$(cat "${ERROR_FILE}" | wc -l)
  if [[ "${ERROR_COUNT}" != "0" ]]; then
    eval "export $(egrep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u $LOGNAME gnome-session)/environ)"
    notify-send "WoW Mod Updater" "$(cat ${ERROR_FILE})"
  fi
  
elif [[ "${NOTIFY_SEND_LEVEL}" == "2" ]]; then
  # NOTIFY_SEND_LEVEL 2 means send a summary of the run. To do
  # this, we'll need to build up a summary
  ADDED=$(grep -i "^Adding" "${LOG_FILE}" | wc -l)
  UPDATED=$(grep -i "^Updating" "${LOG_FILE}" | wc -l)
  ALREADY=$(grep -i "^Already" "${LOG_FILE}" | wc -l)
  ERRORS=$(cat "${ERROR_FILE}" | wc -l)
  eval "export $(egrep -z DBUS_SESSION_BUS_ADDRESS /proc/$(pgrep -u $LOGNAME gnome-session)/environ)"
  notify-send "WoW Mod Updater" "${ADDED} mods added\n${UPDATED} mods updated\n${ALREADY} mods already up-to-date\n${ERRORS} errors encountered"
fi
