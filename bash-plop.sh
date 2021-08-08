#!/bin/bash

RESET_COLOR="\033[0m"
BOLD="\033[1m"
UNDERLINE="\033[4m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"

plop_fatal_error()
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

plop_init()
{
	PLOP_INIT=1
	TESTS_OK=0
	TESTS_KO=0
	TESTS_LK=0
	TESTS_TO=0
	PLOP_TEST_NUM=1
	PLOP_TEST_INPUT="/dev/null"
	PLOP_TEST_OUTPUT="/dev/null"
	PLOP_LINE_LENGTH=80
	PLOP_MIN_NUM_LENGTH=2
	PLOP_LEAK_CMD=""
	PLOP_TIMEOUT_SECONDS=5
	PLOP_TIMED_OUT=0
	exec 3>&1
}

plop_end()
{
	if [ -z "$PLOP_INIT" ] || [ $PLOP_INIT -eq 0 ]
	then
		plop_fatal_error "VF test framework not initialized..."
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

plop_wait_for_timeout()
{
	sleep $PLOP_TIMEOUT_SECONDS
	if kill -0 $1 > /dev/null 2>&1
	then
		touch timed.out > /dev/null 2>&1
		kill $1
	fi
}

plop_timeout_test()
{
	if [ $PLOP_TIMEOUT_SECONDS -gt 0 ]
	then
		"$@" < $PLOP_TEST_INPUT &
		bg_process=$!
		plop_wait_for_timeout $bg_process &
		wait $bg_process
	else
		"$@" < $PLOP_TEST_INPUT
	fi
	PLOP_EXIT_STATUS=$?
	if [ -f timed.out ]
	then
		PLOP_TIMED_OUT=1
		rm -f timed.out > /dev/null 2>&1
	fi
	if ! [ -z "$PLOP_TIMED_OUT" ] && [ $PLOP_TIMED_OUT -gt 0 ]
	then
		return 1
	else
		return 0
	fi
}

plop_test_command()
{
	if [ -z "$PLOP_INIT" ] || [ $PLOP_INIT -eq 0 ]
	then
		plop_fatal_error "VF test framework not initialized..."
	fi
	printf "${BLUE}# %0*d: %-*s  []${RESET_COLOR}" $PLOP_MIN_NUM_LENGTH $PLOP_TEST_NUM $(($PLOP_LINE_LENGTH - 9 - $PLOP_MIN_NUM_LENGTH)) "$PLOP_DESCRIPTION"
	command -v plop_setup > /dev/null 2>&1 && plop_setup
	PLOP_EXIT_STATUS=0
	if ([ -z "$PLOP_SKIP" ] || [ $PLOP_SKIP -eq 0 ]) && [ $# -gt 0 ]
	then
		plop_timeout_test $PLOP_LEAK_CMD "$@" > $PLOP_TEST_OUTPUT 2>&1
	fi
	return $PLOP_EXIT_STATUS
}

plop_test_summary()
{
	if [ -z "$PLOP_SKIP" ] || [ $PLOP_SKIP -eq 0 ]
	then
		if [ -z "$PLOP_TIMED_OUT" ] || [ $PLOP_TIMED_OUT -eq 0 ]
		then
			if [ -z "$PLOP_RESULT_COLOR" ]
			then
				if [ -z "$PLOP_TEST_RESULT" ] || [ "$PLOP_TEST_RESULT" = "OK" ]
				then
					PLOP_RESULT_COLOR=$GREEN
				else
					PLOP_RESULT_COLOR=$RED
				fi
			fi
			case $PLOP_TEST_RESULT in
				"OK")
					TESTS_OK=$(($TESTS_OK + 1));;
				"KO")
					TESTS_KO=$(($TESTS_KO + 1));;
				"LK")
					TESTS_LK=$(($TESTS_LK + 1));;
			esac
		else
			TESTS_TO=$(($TESTS_TO + 1))
			PLOP_TEST_RESULT="TO"
			PLOP_RESULT_COLOR=$RED
		fi
		printf "\r${PLOP_RESULT_COLOR}# %0*d: %-*s [%s]\n${RESET_COLOR}" $PLOP_MIN_NUM_LENGTH $PLOP_TEST_NUM $(($PLOP_LINE_LENGTH - 9 - $PLOP_MIN_NUM_LENGTH)) "$PLOP_DESCRIPTION" "$PLOP_TEST_RESULT"
	else
		printf "\n"
	fi
	command -v plop_teardown > /dev/null 2>&1 && plop_teardown
	PLOP_TEST_NUM=$(($PLOP_TEST_NUM + 1))
	PLOP_TEST_INPUT="/dev/null"
	PLOP_TEST_OUTPUT="/dev/null"
	PLOP_DESCRIPTION=""
	PLOP_SKIP=0
	PLOP_TIMED_OUT=0
	PLOP_RESULT_COLOR=""
}

plop_pipe_cmd()
{
	cmd=$1
	shift 1
	echo $@ | $cmd
}
