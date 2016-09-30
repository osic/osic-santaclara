#!/usr/bin/env bash
# Not a test as much as an exercise of all options. Shows befor and after results of each command.
# Note: create cobbler system named 'test-test' before running.
test::report(){
	cobbler system report --name test-test | grep -e name -e "^Kernel Options\s*:.*"
}
test::setup(){
	cobbler system edit --name test-test --kopts=""
}
echo "Running all options..."
test::setup
echo "**Insuffienct args**"

echo "****No args****"
./set_console.sh
echo "****One args****"
./set_console.sh test-test

echo ""
echo "**CLI args**"

echo "****Two Args****"
test::setup
test::report
./set_console.sh test-test em1
test::report

echo "****Three Args****"
test::setup
test::report
./set_console.sh test-test em1 "interface=em1 console=tty0 console=ttyS0,115200n8"
test::report

echo ""
echo "**File args**"
echo "****One Arg****"
test::setup
test::report
./set_console.sh -f test-set_console.csv
test::report

echo "****Two Arg****"
test::setup
test::report
./set_console.sh -f test-set_console.csv "interface=em1 console=tty0 console=ttyS0,115200n8"
test::report