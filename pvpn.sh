#!/usr/bin/env bash

DEFAULT_RETRY=3

PVPN_SCRIPT_NAME="$(basename ${BASH_SOURCE:-$0})"
CONNECT_COMMAND_DESCRIPTION="connect to SERVER (default to fastest server)"

EXIT_CODE_PROTONVPN_NOT_INSTALLED=1
EXIT_CODE_CONNECTION_ERROR=2
EXIT_CODE_INVALID_COMMAND=3
EXIT_CODE_INVALID_ARG=4
EXIT_CODE_INVALID_PROTOCOL=5
EXIT_CODE_INVALID_RETRY_VALUE=6
EXIT_CODE_FLAG_SET_TWICE=7
EXIT_CODE_FLAG_SET_WITH_NO_VALUE=8
EXIT_CODE_TERMINATED_BY_USER=9
EXIT_CODE_UNHANDLED_ERROR=10

function print_intro() {
    echo "protonvpn-cli with retry functionality"
}

function print_usage_and_commands() {
    echo -e "Usage: \e[1m$PVPN_SCRIPT_NAME\e[0m [\e[1mCOMMAND\e[0m (default to 'c' or 'connect')]"
    echo
    echo -e "\e[1mCOMMAND:\e[0m"
    echo -e "\tc, connect [-p|--protocol|-r|--retry] [SERVER]"
    echo -e "\t\t\t $CONNECT_COMMAND_DESCRIPTION."
    echo -e "\t\t\t Use '$PVPN_SCRIPT_NAME connect --help' to know more specific arguments"
    echo -e "\td, disconnect\t disconnect from vpn"
    echo -e "\tr, reconnect\t reconnect to previously connected server"
    echo -e "\ts, status\t connection status"
    echo -e "\tn, select\t select server manually through ncurses-ui"
    echo -e "\th, help\t\t show the help message"
}

function print_help() {
    print_intro
    echo
    print_usage_and_commands
    echo
    echo -e "set \e[1mDEBUG\e[0m env variable to a non-zero value to running in debug mode."
    echo
    echo -e "\e[1mExit Codes Definition:\e[0m"
    echo -e "\t$EXIT_CODE_PROTONVPN_NOT_INSTALLED => EXIT_CODE_PROTONVPN_NOT_INSTALLED"
    echo -e "\t$EXIT_CODE_CONNECTION_ERROR => EXIT_CODE_CONNECTION_ERROR"
    echo -e "\t$EXIT_CODE_INVALID_COMMAND => EXIT_CODE_INVALID_COMMAND"
    echo -e "\t$EXIT_CODE_INVALID_ARG => EXIT_CODE_INVALID_ARG"
    echo -e "\t$EXIT_CODE_INVALID_PROTOCOL => EXIT_CODE_INVALID_PROTOCOL"
    echo -e "\t$EXIT_CODE_INVALID_RETRY_VALUE => EXIT_CODE_INVALID_RETRY_VALUE"
    echo -e "\t$EXIT_CODE_FLAG_SET_TWICE => EXIT_CODE_FLAG_SET_TWICE"
    echo -e "\t$EXIT_CODE_FLAG_SET_WITH_NO_VALUE => EXIT_CODE_FLAG_SET_WITH_NO_VALUE"
    echo -e "\t$EXIT_CODE_TERMINATED_BY_USER => EXIT_CODE_TERMINATED_BY_USER"
    echo -e "\t$EXIT_CODE_UNHANDLED_ERROR => EXIT_CODE_UNHANDLED_ERROR"
}

function print_connect_help() {
    echo -e "Usage: $PVPN_SCRIPT_NAME \e[1mconnect\e[0m [ARGS] [SERVER]"
    echo -e "$CONNECT_COMMAND_DESCRIPTION"
    echo
    echo -e "\e[1mSERVER\e[0m:\n\tconnect to specified server (ie: CH#4, CH-US-1, HK5-Tor)"
    echo -e "\e[1mARGS\e[0m:"
    echo -e "\t-p, --protocol PROTO\t connect via PROTO protocol (possible values: tcp|udp)"
    echo -e "\t-r, --retry N\t\t retry N times before giving up to connect (defaul to $DEFAULT_RETRY)"
}

function print_install_guide() {
    echo "Looks like 'ProtonVPN' is not install on your system."
    echo -n "To install 'ProtonVPN', open this link on your web browser: "
    echo -e "'https://protonvpn.com/download-linux'"
}

function handle_127_exit_code() {
    if [ "$1" -eq "127" ]; then
        print_install_guide
        exit $EXIT_CODE_PROTONVPN_NOT_INSTALLED
    fi
}

function status() {
    protonvpn-cli s 2>/dev/null
    handle_127_exit_code "$?"
}

function select_() {
    protonvpn-cli c 2>/dev/null
    handle_127_exit_code "$?"
}

function disconnect() {
    protonvpn-cli d 2>/dev/null
    handle_127_exit_code "$?"
}

function reconnect() {
    protonvpn-cli r 2>/dev/null
    handle_127_exit_code "$?"
}

function connect_vpn() {
    local output="$(protonvpn-cli c "$1" 2>&1)"
    local result="$?"

    if [ "$result" -ne "0" ]; then
        
        handle_127_exit_code "$result"

        echo "$output" | egrep -i 'failed' >/dev/null 2>&1
        local conn_failed="$?"
        #
        # check if connection timeouts so try again.
        # else error is not recoverable and should break immidiatly
        #
        if [ "$conn_failed" -eq "0" ]; then
            return "$result"
        else
            #
            # stripe leading "Setting up ProtonVPN" and "Connecting to ProtonVPN" headers and empty lines from output error message
            #
            output="$(echo -e "$output" | egrep -iv "setting up protonvpn|connecting to protonvpn|^$")"
            echo -e "$output"
            exit $EXIT_CODE_UNHANDLED_ERROR
        fi
    
    else
        #
        # protonvpn-cli bug that fail to connect but exit with zero code :(
        #        
        
        ###################################################
        if [ -n "$DEBUG" ]; then
            echo "[DEBUG] protonvpn-cli output on success:"
            echo -e "$output"
        fi
        ###################################################

        echo "$output" | egrep -i 'unable to connect to protonvpn|an unknown error has occured' >/dev/null 2>&1
        local unhandled_error="$?"

        if [ "$unhandled_error" -eq "0" ]; then
            output="$(echo -e "$output" | egrep -iv "setting up protonvpn|connecting to protonvpn|^$")"
            echo -e "$output"

            ############################################
            if [ -n "$DEBUG" ]; then
                echo "[DEBUG] retrying..."
                return -1
            fi
            ###########################################

            echo -e "unhandled 'protonvpn-cli' backend error happend.\nfor more details run '$PVPN_SCRIPT_NAME' in debug mode."
            exit $EXIT_CODE_UNHANDLED_ERROR
        fi
        
    fi
    
}

function connect() {

    local connection_args=""
    local server=""
    local protocol=""
    local retry=""

    #
    # parse argumments passed to "c" or "connect" command
    # 
    while [ -n "$1" ]; do
        case "$1" in
            -p | --protocol)
                if [ -n "$protocol" ]; then
                    echo "error: '-p|--protocol' flag set twice"
                    echo
                    print_connect_help
                    exit $EXIT_CODE_FLAG_SET_TWICE
                fi
                if [ -z "$2" ]; then
                    echo "error: '-p|--protocol' flag set but no protocol specified"
                    echo
                    print_connect_help
                    exit $EXIT_CODE_FLAG_SET_WITH_NO_VALUE
                fi
                shift
                protocol="$1"
            ;;    
            -r | --retry)
                if [ -n "$retry" ]; then
                    echo "error: '-r|--retry' flag set twice"
                    echo
                    print_connect_help
                    exit $EXIT_CODE_FLAG_SET_TWICE
                fi
                if [ -z "$2" ]; then
                    echo "error: '-r|--retry' flag set but no value specified"
                    echo
                    print_connect_help
                    exit $EXIT_CODE_FLAG_SET_WITH_NO_VALUE
                fi
                shift
                retry="$1"
            ;;
            -h | --help)
                print_connect_help
                exit 0
            ;;
            *)
                if [ -n "$server" ]; then
                    echo "error: invalid argument '$1'"
                    exit $EXIT_CODE_INVALID_ARG
                fi
                server="$1"
        esac
        shift
    done

    if [ -z "$protocol" ]; then
        protocol="udp"    
    elif [ "$protocol" != "udp" ] && [ "$protocol" != "tcp" ]; then
        echo "error: invalid protocol '$protocol'"
        echo
        print_connect_help
        exit $EXIT_CODE_INVALID_PROTOCOL
    fi
      
    if [ -z "$retry" ]; then
        retry="$DEFAULT_RETRY"
    fi
    if ! echo "$retry" | egrep -q '^[0-9]+$'; then
        echo "error: invalid retry value '$retry'"
        echo
        print_connect_help
        exit $EXIT_CODE_INVALID_RETRY_VALUE 
    fi
    if [ "$retry" -lt 0 ]; then
        echo -e "negative retry value '$retry'. default to '$DEFAULT_RETRY'..."
        retry="$DEFAULT_RETRY"
    fi

    if [ -z "$server" ]; then
        connection_args="-f -p $protocol"
    else
        connection_args="$server -p $protocol"
    fi

    ###########################################################################################################
    if [ -n "$DEBUG" ]; then
        echo -e "[DEBUG] server: $server, protocol: $protocol, retry: $retry, connection args: $connection_args"
    fi
    ###########################################################################################################

    local tried_counts=0
    local result=0

    #
    # retry facility
    #
    for _ in $(seq "$(expr 1 + "$retry")"); do

        connect_vpn $connection_args
        result=$?
    
        if [ "$result" -ne 0 ]; then
            if [ "$tried_counts" -lt "$retry" ]; then
                ((++tried_counts))
                clear_the_line
                echo -ne "retrying within 1 second ($tried_counts/$retry)...\r"
                sleep 1
            fi
        else
            break
        fi

    done

    clear_the_line

    if [ "$result" -ne 0 ]; then
        script_name="$(basename ${BASH_SOURCE[0]:-$0})"
        if [ "$retry" -gt 0 ]; then
            echo "cannot connect to server (retried $retry times). try '$script_name n|select'"
        else
            echo "cannot connect to server. try '$script_name n|select'"
        fi
        exit $EXIT_CODE_CONNECTION_ERROR
    fi
  
    status
}

####################################################################################

function clear_the_line() {
    echo -ne "                                                      \r"
}

function ctrl_c() {
    clear_the_line
    echo -e "** opration terminated by user..."
    exit $EXIT_CODE_TERMINATED_BY_USER
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

if [ -z "$1" ]; then
    connect -r "$DEFAULT_RETRY"
    exit $?
fi

case "$1" in
  c | connect)
      shift
      connect "$@"
      ;;
  d | disconnect)
      disconnect
      ;;
  r | reconnect)
      reconnect
      ;;
  n | select)
      select_
      ;;
  s | status)
      status
      ;;
  h | help | -h | --help)
      print_help
      ;;
  *)
      echo "invalid command '$1'"
      echo
      print_usage_and_commands
      exit $EXIT_CODE_INVALID_COMMAND
      ;;
esac
