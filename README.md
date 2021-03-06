```
protonvpn-cli with retry functionality

Usage: pvpn.sh [COMMAND (default to 'c' or 'connect')]

COMMAND:
	c, connect [-p|--protocol|-r|--retry] [SERVER]
			 connect to SERVER (default to fastest server).
			 Use 'pvpn.sh connect --help' to know more specific arguments
	d, disconnect	 disconnect from vpn
	r, reconnect	 reconnect to previously connected server
	s, status	 connection status
	n, select	 select server manually through ncurses-ui
	h, help		 show the help message

set DEBUG env variable to a non-zero value to running in debug mode.

Exit Codes Definition:
	1 => EXIT_CODE_PROTONVPN_NOT_INSTALLED
	2 => EXIT_CODE_CONNECTION_ERROR
	3 => EXIT_CODE_INVALID_COMMAND
	4 => EXIT_CODE_INVALID_ARG
	5 => EXIT_CODE_INVALID_PROTOCOL
	6 => EXIT_CODE_INVALID_RETRY_VALUE
	7 => EXIT_CODE_FLAG_SET_TWICE
	8 => EXIT_CODE_FLAG_SET_WITH_NO_VALUE
	9 => EXIT_CODE_TERMINATED_BY_USER
	10 => EXIT_CODE_UNHANDLED_ERROR
```
