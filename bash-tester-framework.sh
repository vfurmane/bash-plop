#!/bin/bash

RESET_COLOR="\033[0m"
BOLD="\033[1m"
UNDERLINE="\033[4m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"

vf_fatal_error()
{
	if [ -z "$1" ]
	then
		message="fatal error"
	else
		message="$1"
	fi
	if [ -z "$2" ]
	then
		exit_status=1
	else
		exit_status=$2
	fi
	printf "${RED}$message${NC}\n"
	exit $exit_status
}

vf_init()
{
	commands_needed=("awk")
	for command_needed in "${commands_needed[@]}"
	do
		command -v $command_needed > /dev/null 2>&1 || vf_fatal_error "'$command_needed' command not found..."
	done
	VF_INIT=1
	TESTS_OK=0
	TESTS_KO=0
	TESTS_LK=0
	TESTS_TO=0
	TEST_NUM=0
	LEAK_CMD=""
	TIMEOUT_SECONDS=5
	exec 3>&1
}

vf_end()
{
	if [ -z "$VF_INIT" ] || [ $VF_INIT -eq 0 ]
	then
		vf_fatal_error "VF test framework not initialized..."
	fi
	exec 1>&3
	printf "\n\n"
	printf "\t${BOLD}Summary${NC}\n\n" > /dev/stdout
	
	[ $TESTS_OK -gt 0 ] && printf "${GREEN}$TESTS_OK OK${NC}"
	[ $TESTS_OK -gt 0 ] && [ $TESTS_KO -gt 0 ] && printf " - "
	[ $TESTS_KO -gt 0 ] && printf "${RED}$TESTS_KO KO${NC}"
	([ $TESTS_OK -gt 0 ] || [ $TESTS_KO -gt 0 ]) && [ $TESTS_LK -gt 0 ] && printf " - "
	[ $TESTS_LK -gt 0 ] && printf "${RED}$TESTS_LK LK${NC}"
	([ $TESTS_OK -gt 0 ] || [ $TESTS_KO -gt 0 ] || [ $TESTS_LK -gt 0 ]) && [ $TESTS_TO -gt 0 ] && printf " - "
	[ $TESTS_TO -gt 0 ] && printf "${RED}$TESTS_TO TO${NC}"
	printf "\n\n"
	
	if [ $TESTS_KO -eq 0 ] && [ $TESTS_LK -eq 0 ] && [ $TESTS_TO -eq 0 ]
	then
		exit 0
	else
		exit 1
	fi
}

vf_wait_for_timeout()
{
	sleep $TIMEOUT_SECONDS
	if kill -0 $1 > /dev/null 2>&1
	then
		kill $1
		VF_TIMED_OUT=1
	fi
}

vf_timeout_test()
{
	if [ $TIMEOUT_SECONDS -gt 0 ]
	then
		$@ &
		bg_process=$!
		vf_wait_for_timeout $bg_process &
		wait $bg_process
	else
		$@
	fi
	VF_EXIT_STATUS=$?
	if [ -z "$VF_TIMED_OUT" ] || [ $VF_TIMED_OUT -eq 0 ]
	then
		return 0
	else
		return 1
	fi
	return $status_code
}

vf_test_command()
{
	if [ -z "$VF_INIT" ] || [ $VF_INIT -eq 0 ]
	then
		vf_fatal_error "VF test framework not initialized..."
	fi
	TEST_NUM=$(echo "$TEST_NUM 1" | awk '{printf "%02d", $1 + $2}') # dynamic leading 0s
	printf "${BLUE}# $num: %-69s  []${NC}" "$VF_DESCRIPTION"
	VF_EXIT_STATUS=0
	if ([ -z "$VF_SKIP" ] || [ $VF_SKIP -eq 0 ]) && ! [ -z "$1" ]
	then
		vf_timeout_test $LEAK_CMD $1
	fi
	return $VF_EXIT_STATUS
}

vf_test_summary()
{
	if [ -z "$VF_RESULT_COLOR" ]
	then
		if [ -z "$VF_TEST_RESULT" ] || [ "$VF_TEST_RESULT" = "OK" ]
		then
			VF_RESULT_COLOR=$GREEN
		else
			VF_RESULT_COLOR=$RED
		fi
	fi
	case $VF_TEST_RESULT in
		"OK")
			TEST_OK=$(($TEST_OK + 1));;
		"KO")
			TEST_KO=$(($TEST_KO + 1));;
		"LK")
			TEST_LK=$(($TEST_LK + 1));;
		"TO")
			TEST_TO=$(($TEST_TO + 1));;
	esac
	if [ -z "$VF_SKIP" ] || [ $VF_SKIP -eq 0 ]
	then
		printf "\r${VF_RESULT_COLOR}# $num: %-69s [%s]\n${NC}" "$description" "$VF_TEST_RESULT"
	else
		printf "\n"
	fi
	VF_DESCRIPTION=""
	VF_SKIP=0
	VF_TIMED_OUT=0
	VF_RESULT_COLOR=""
}
