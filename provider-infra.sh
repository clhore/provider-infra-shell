#!/usr/bin/bash

# Author: Adrián Luján Muñoz (aka clhore)
# TertiaOptio

# [READ-ONLY] Colours Code
readonly GREEN="\e[0;32m\033[1m"
readonly END="\033[0m\e[0m"
readonly RED="\e[0;31m\033[1m"
readonly BLUE="\e[0;34m\033[1m"
readonly yellow="\e[0;33m\033[1m"
readonly purple="\e[0;35m\033[1m"
readonly turquoise="\e[0;36m\033[1m"
readonly gray="\e[0;37m\033[1m"

# [READ-ONLY] Absolute Path
declare -r SSH='/usr/bin/ssh'
declare -r SCP='/usr/bin/scp'
declare -r CURL='/usr/bin/curl'
declare -r QM='/usr/sbin/qm'
declare -r FIND='/usr/bin/find'
declare -r AWK='/usr/bin/awk'
declare -r RM='/usr/bin/rm'
declare -r ECHO='/usr/bin/echo'
declare -r MKDIR='/usr/bin/mkdir'

# [VARIABLES] PROJECT
declare -r DEFAULD_PROJECT_PATH="$PWD"
#declare PROJECT_PATH="$PWD"

# [VARIABLES] Provider Options
declare -r TMP_DIR='/var/tmp'
declare -r TMP_FILE='.tmp-tertiaoptio-provider'
declare -r TMP_PROVIDER='tertiaoptio-auto-provider.sh'

# [VARIABLES] Infra Deployment
declare DIR_INFRA="scripts-infra"
#declare -r FILES_INFRA=$($FIND $DIR_INFRA -type f | $AWK -F '/' '{print $NF}' | tee $PROJECT_PATH/$TMP_FILE)
#declare -r FILES_INFRA=$(printf ${FILES_INFRA_PATH} | $AWK -F '/' '{print $NF}')

function help_panel()
{
    printf 'provider-infra.sh [OPTIONS]\n'; exit 0;
}

function error_log()
{
  case $1 in
     00)
       $ECHO -e "${RED}:: Error path${RED}";
     ;;

     22)
       $ECHO -e "${RED}:: Error list files${RED}";
     ;;
  esac;
}

function search_list()
{
  local LIST=(${1}); local ITEM=${2};

  [[ " ${LIST[*]} " == *" ${ITEM} "* ]] && return 0; return 1;
}

function check_rute(){ [ -r "$1" ] || return 1; return 0; }

function defauld_value()
{
  # Work directory
  [ -z $PROJECT_PATH ] && PROJECT_PATH=$DEFAULD_PROJECT_PATH;

  # Path env file
  [ -z $ENV_FILE ] && ENV_FILE='.env.sh'

  return 0;
}

function check_not_value_flash()
{
  local LIST=($@)
  # Show HelpPanel
  search_list "${LIST[*]}" '--help'   && help_panel;
  search_list "${LIST[*]}" '-h'       && help_panel;

  # Select Action
  search_list "${LIST[*]}" 'init'     && declare -g -r INFRA_ACTION=0;
  search_list "${LIST[*]}" 'apply'    && declare -g -r INFRA_ACTION=1;
  search_list "${LIST[*]}" 'destroy'  && declare -g -r INFRA_ACTION=2;

  return 0;
}

function check_flash()
{
  local -i INDEX=1; local -A CHECK=()
  local -A ARGUMENTS=(); local -A VARIABLES=()

  VARIABLES["--path"]="PROJECT_PATH"
  VARIABLES["--infra-path"]="PROJECT_PATH"
  VARIABLES["--env"]="ENV_FILE"
  VARIABLES["--env-file"]="ENV_FILE"

  VARIABLES["-r"]="PROJECT_PATH"
  VARIABLES["-e"]="ENV_FILE"

  for i in "$@"; do
    INDEX=INDEX+1; ARGUMENTS[$INDEX]=$i
    local PREV_INDEX=$((INDEX-1));

    [[ $i == *"="* ]] && ARGUMENT_LABEL=${i%=*} || {
      ARGUMENT_LABEL=${ARGUMENTS[$PREV_INDEX]}
    }

    [[ -n $ARGUMENT_LABEL ]] || continue
    [[ -n ${VARIABLES[$ARGUMENT_LABEL]} ]] || continue

    search_list "${CHECK[*]}" "${VARIABLES[$ARGUMENT_LABEL]}" && {
      #error_log 00 'Error: Formato incorrecto'
      return 1
    }; CHECK+=${VARIABLES[$ARGUMENT_LABEL]}

    [[ $i == *"="* ]] && {
      declare -g ${VARIABLES[$ARGUMENT_LABEL]}=${i#$ARGUMENT_LABEL=};
      continue
    }; declare -g ${VARIABLES[$ARGUMENT_LABEL]}=${ARGUMENTS[$INDEX]}
  done; return 0
}

function check_exit_status()
{
    [ "${1}" == "0" ] || { printf "${RED}[ERROR]${END}\n"; exit 1;};
    printf "${GREEN}[OK]${END}\n";
}

function init_structure()
{
  $MKDIR -p ssh $DIR_INFRA/infra-create $DIR_INFRA/infra-delete $DIR_INFRA/ssh || return 1;
  test -f $PROJECT_PATH/$ENV_FILE &>/dev/null || printf '
  #!/usr/bin/bash

  # Author: Adrián Luján Muñoz (aka clhore)
  # TertiaOptio

  # [VARIABLES] PROJECT
  declare DIR_INFRA="%s"

  # [INFRA][ON-PREMISE]
  declare -A HYPERVISOR=()
  HYPERVISOR["TYPE"]="proxmox"
  HYPERVISOR["SSH_HOST"]=""
  HYPERVISOR["SSH_PORT"]="22"
  HYPERVISOR["SSH_USER"]="pve"
  HYPERVISOR["SSH_PRIVATE_KEY_FILE"]="ssh/id_rsa_bastion"
  ' $DIR_INFRA > $PROJECT_PATH/$ENV_FILE
  return 0;
}

function main()
{
  [ $INFRA_ACTION -eq 0 ] && { # init 
    printf "[INIT] Creating base directories ";
    init_structure; check_exit_status "$?"; exit 0;
  }

  test -f $PROJECT_PATH/$ENV_FILE &>/dev/null || {
    printf "${RED}[ERROR]${END}} Dont exist env file, exec 'provider-infra.sh init'"; exit 1
  }

  # Import env file
  source $PROJECT_PATH/$ENV_FILE

  # If input rute exit, exec main function
  check_rute "$PROJECT_PATH/$DIR_INFRA" &>/dev/null || exit 1; 

  [ $INFRA_ACTION -eq 1 ] && { # apply
    local ACTION_RUTE=$PROJECT_PATH/$DIR_INFRA/infra-create
  }

  [ $INFRA_ACTION -eq 2 ] && { # destroy
    local ACTION_RUTE=$PROJECT_PATH/$DIR_INFRA/infra-delete
  }

  # [INFRA][COPY-FILE]
  $SCP -i ${HYPERVISOR['SSH_PRIVATE_KEY_FILE']} -P ${HYPERVISOR['SSH_PORT']} \
        $ACTION_RUTE/* ${HYPERVISOR['SSH_USER']}@${HYPERVISOR['SSH_HOST']}:$TMP_DIR 

  declare -r FILES_INFRA=$($FIND $ACTION_RUTE -type f | $AWK -F '/' '{print $NF}')

  {
    while IFS= read -r FILE_S; do printf "sudo chmod +x ${TMP_DIR}/${FILE_S} && sudo ${TMP_DIR}/${FILE_S}\n";
        printf "sudo rm -f ${TMP_DIR}/${FILE_S}\n"; done <<< $FILES_INFRA  
  } | $SSH \
  -i ${HYPERVISOR['SSH_PRIVATE_KEY_FILE']} -p ${HYPERVISOR['SSH_PORT']} ${HYPERVISOR['SSH_USER']}@${HYPERVISOR['SSH_HOST']} \
  "cat - > $TMP_DIR/$TMP_PROVIDER && bash /var/tmp/tertiaoptio-auto-provider.sh; #rm -f /var/tmp/tertiaoptio-auto-provider.sh"
}

check_not_value_flash $@ || exit 1;
check_flash $@ && defauld_value || exit 1

[ -v INFRA_ACTION ] || help_panel;

main;