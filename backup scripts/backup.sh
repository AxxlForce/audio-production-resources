#!/bin/sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD=$(tput bold)
NORM=$(tput sgr0)

config_read_file() 
{
    (grep -E "^${2}=" -m 1 "${1}" 2>/dev/null || echo "VAR=__UNDEFINED__") | head -n 1 | cut -d '=' -f 2-;
}

config_get() 
{
    val="$(config_read_file locations.cfg "${1}")";
    if [ "${val}" = "__UNDEFINED__" ]; then
        val="$(config_read_file config.cfg.defaults "${1}")";
    fi
    printf -- "%s" "${val}";
}

function pushProject()
{
	echo TODO
}

function pullProject()
{
	destination="$4/$1"

	if [ ! -d "$destination" ]; then
  		echo "$1 not found at $3"
	fi

	echo
	echo "are you sure yo want to pull"
	echo
	echo "${GREEN}$2:$3/$1${NC}"
	echo
	echo "into"
	echo
	echo "${RED}${BOLD}$destination${NC}${NORM}?"

	read -p "[y/n]" -n 1 -r
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		echo
	  echo "abort by user..."
	  exit 0
	fi

	echo
	echo
	echo "pulling project $1 from $2:$3 into $4"
	echo

	source="$2:\"'$3/$1/'\""

  	eval rsync -rltDOz --progress --include='*.RPP' --include='*.rpp' --include='*.wav' --include='*/' --exclude='*' "$source" "'$destination'" --progress
}

function usage()
{
	echo
	echo "USAGE"
	echo

	exit 1
}

function check_configuration()
{
	wip_remote_host="$(config_get wip_remote_host | sed 's:/*$::')"
	if [ "$wip_remote_host" == "__UNDEFINED__" ]; then
		echo "\nremote host is not defined"
		usage
	fi

	wip_remote_path="$(config_get wip_remote_path | sed 's/[ \t]*$//;s:/*$::')"
	if [ "$wip_remote_path" == "__UNDEFINED__" ]; then
		echo "\nremote path is not defined"
		usage
	fi

	wip_local_path="$(config_get wip_local_path | sed 's/[ \t]*$//;s:/*$::')"
	if [ "$wip_local_path" == "__UNDEFINED__" ]; then
		echo "\nlocal path is not defined"
		usage
	fi
}

if [ $# -eq 0 ]; then
    echo "\nno arguments provided"
    usage
fi

while [ "$1" != "" ]; do
    param=`echo $1 | awk -F= '{print $1}'`
    value=`printf "%s\n" $1 | sed 's/^[^=]*=//g'`
    if [ "$value" = "$param" ]; then
        shift
        value=$1
    fi

	case $param in
	        -h | --help)
	            usage
	            ;;
	        pull)
				echo "$value"

				if [ -z "$value" ]; then
				    echo "no project specified"
				    usage
				fi

	            check_configuration
				pullProject $value "$wip_remote_host" "$wip_remote_path" "$wip_local_path"
				exit 0
	            ;;
	        push)
				if [ -z "$value" ]; then
				    echo "no project specified"
				    usage
				fi

	            check_configuration
	            pushProject
	            echo push
	            ;;
			*)
				echo "ERROR: unknown parameter \"$param\""
	            usage
	            ;;
	esac

	shift

done














