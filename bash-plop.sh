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
	printf "${RED}$message${RESET_COLOR}\n"
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
	VF_TEST_NUM=1
	VF_TEST_OUTPUT="> /dev/null 2>&1"
	VF_LINE_LENGTH=80
	VF_MIN_NUM_LENGTH=2
	VF_LEAK_CMD=""
	VF_TIMEOUT_SECONDS=5
	VF_TIMED_OUT=0
	exec 3>&1
}

vf_end()
{
	if [ -z "$VF_INIT" ] || [ $VF_INIT -eq 0 ]
	then
		vf_fatal_error "VF test framework not initialized..."
	fi
	exec 1>&3
	printf "\n"
	[ $TESTS_OK -gt 0 ] && printf "${GREEN}$TESTS_OK OK${RESET_COLOR}"
	[ $TESTS_OK -gt 0 ] && [ $TESTS_KO -gt 0 ] && printf " - "
	[ $TESTS_KO -gt 0 ] && printf "${RED}$TESTS_KO KO${RESET_COLOR}"
	([ $TESTS_OK -gt 0 ] || [ $TESTS_KO -gt 0 ]) && [ $TESTS_LK -gt 0 ] && printf " - "
	[ $TESTS_LK -gt 0 ] && printf "${RED}$TESTS_LK LK${RESET_COLOR}"
	([ $TESTS_OK -gt 0 ] || [ $TESTS_KO -gt 0 ] || [ $TESTS_LK -gt 0 ]) && [ $TESTS_TO -gt 0 ] && printf " - "
	[ $TESTS_TO -gt 0 ] && printf "${RED}$TESTS_TO TO${RESET_COLOR}"
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
	sleep $VF_TIMEOUT_SECONDS
	if kill -0 $1 > /dev/null 2>&1
	then
		kill $1
	fi
}

vf_timeout_test()
{
	if [ $VF_TIMEOUT_SECONDS -gt 0 ]
	then
		$@ &
		bg_process=$!
		vf_wait_for_timeout $bg_process &
		wait $bg_process
	else
		$@
	fi
	VF_EXIT_STATUS=$?
	if [ $VF_EXIT_STATUS -eq 143 ]
	then
		VF_TIMED_OUT=1
		return 1
	else
		return 0
	fi
}

vf_test_command()
{
	if [ -z "$VF_INIT" ] || [ $VF_INIT -eq 0 ]
	then
		vf_fatal_error "VF test framework not initialized..."
	fi
	printf "${BLUE}# %0*d: %-*s  []${RESET_COLOR}" $VF_MIN_NUM_LENGTH $VF_TEST_NUM $(($VF_LINE_LENGTH - 9 - $VF_MIN_NUM_LENGTH)) "$VF_DESCRIPTION"
	VF_EXIT_STATUS=0
	if ([ -z "$VF_SKIP" ] || [ $VF_SKIP -eq 0 ]) && [ $# -gt 0 ]
	then
		vf_timeout_test $VF_LEAK_CMD $@ > $VF_TEST_OUTPUT 2>&1
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
			TESTS_OK=$(($TESTS_OK + 1));;
		"KO")
			TESTS_KO=$(($TESTS_KO + 1));;
		"LK")
			TESTS_LK=$(($TESTS_LK + 1));;
		"TO")
			TESTS_TO=$(($TESTS_TO + 1));;
	esac
	if [ -z "$VF_SKIP" ] || [ $VF_SKIP -eq 0 ]
	then
		printf "\r${VF_RESULT_COLOR}# %0*d: %-*s [%s]\n${RESET_COLOR}" $VF_MIN_NUM_LENGTH $VF_TEST_NUM $(($VF_LINE_LENGTH - 9 - $VF_MIN_NUM_LENGTH)) "$VF_DESCRIPTION" "$VF_TEST_RESULT"
	else
		printf "\n"
	fi
	VF_TEST_NUM=$(($VF_TEST_NUM + 1))
	VF_TEST_OUTPUT="> /dev/null 2>&1"
	VF_DESCRIPTION=""
	VF_SKIP=0
	VF_TIMED_OUT=0
	VF_RESULT_COLOR=""
}
