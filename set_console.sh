#!/bin/bash
setconsole::usage(){
	cat <<EOF
	Usage: set_console.sh <system_name> <interface> [<console string>]
	Set system property to use serial console for given system and interface
	options:
	-f use file in "OSIC input.csv format" for input

	Examples using args:
	set_console.sh hasvcs-compute01 em1
	set_console.sh hasvcs-compute01 em1 "{'interface': '%s', 'console': ['tty0', 'ttyS0,115200n8']}"

	Examples using file:
	set_console.sh -f input.csv
	set_console.sh -f input.csv "{'interface': '%s', 'console': ['tty0', 'ttyS0,115200n8']}"

	Examples of advanced usage:
	cobbler system list | grep hasvcs | awk '{print "./set_console.sh "$1" em1"}' | /bin/bash
EOF
	exit 0
}
setconsole::exec(){
	system=$1
	interface=$2
	console_string=$3
	console_string=${console_string[@]}
	printf -v final_string "$console_string" "$interface"
	cobbler system edit --name ${system} --kopts="$final_string"

}
setconsole::main(){
	if [[ $# -lt 2 ]]
	then
		setconsole::usage
	fi
	console_string=""
	default_console_string="interface=%s console=tty0 console=ttyS0,115200n8"
	# console string is always param3 if passed
	if [[ -n "$3" ]]
	then
		# use input string
		args=($@)
		#printf "'%s' " "$@";
		unset args[0]
		unset args[1]
		console_string=${args[@]}
	else
		console_string=$default_console_string
	fi
	if [[ $1 == '-f' ]]
	then
		if [[ -n "$2" ]]
		then
			#do file
			while read -r line;
			do
				if [[ -n $line ]]
				then
					OLDIFS=$IFS
					IFS=',';arr=($line)
					IFS=$OLDIFS
					setconsole::exec "${arr[0]}" "${arr[6]}" "$console_string"

					IFS=$OLDIFS
				fi
			done < $2
		else
			# no file passd, exit
			setconsole::usage
		fi
	else
		# do arg input
		setconsole::exec "$1" "$2" "$console_string"
	fi
}
setconsole::main $@
