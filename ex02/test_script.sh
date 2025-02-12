#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if AddressSanitizer is enabled
ASAN_ENABLED=0
if [ -f .asan_enabled ]; then
	ASAN_ENABLED=1
fi

# Run norminette check
echo "Running norminette check..."
output=$(norminette 2>&1)
if [ $? -ne 0 ]; then
	echo "$output" | grep -E --color=always "Error|Warning|Norme"
	echo -e "${RED}Norminette check failed${NC}"
else
	echo -e "${GREEN}Norminette check passed${NC}"
fi

# Compile the files using make
echo "Compiling the program..."
make > /dev/null 2> make_errors.log
if [ $? -ne 0 ]; then
	echo -e "${RED}Compilation failed${NC}"
	cat make_errors.log
	rm -f make_errors.log
	exit 1
else
	rm -f make_errors.log
	echo -e "${GREEN}Compilation succeeded${NC}"
fi

# Function to create test files
create_files() {
	echo "Creating test files..."
	echo "Hello, World!" > simple.txt
	touch empty.txt
	head -c 16 /dev/urandom > binary.dat
	yes "This is a large file." | head -n 10000 > large.txt
	echo '!@#$%^&*()_+{}|:"<>?' > special_chars.txt
	echo "Restricted access" > restricted.txt
	chmod 000 restricted.txt
	echo -e "${GREEN}Test files created.${NC}"
}

# Function to generate a separator line of a given length
generate_separator() {
	local length=$1
	local separator=""
	for ((i=0; i<length; i++)); do
		separator="${separator}="
	done
	echo "$separator"
}

# Assign the longest test to a variable
longest_test="$> (echo \"input1\"; echo \"input2\"; ) | PROGRAM -c 5 non_existent.txt - simple.txt - empty.txt | cat -e"
separator=$(generate_separator $((${#longest_test} + 2)))

# Function to run a test and check the result
run_test() {
	local description=$1
	local option=$2
	local value=$3
	shift 3
	local files=("$@")

	echo "$separator"

	echo "$> PROGRAM $option $value ${files[*]} | cat -e"
	expected=$(tail "$option" "$value" "${files[@]}" 2>&1)
	output=$(./ft_tail "$option" "$value" "${files[@]}" 2>&1)

	# Normalize program names in the output
	expected=$(echo "$expected" | cat -e | sed 's/^tail/PROGRAM/')
	output=$(echo "$output" | cat -e | sed 's/^\.\/ft_tail/PROGRAM/')

	if [ "$output" == "$expected" ]; then
		if [ -n "$ASAN_ENABLED" ] && [ "$ASAN_ENABLED" -eq 1 ] && [ -n "$asan_exit_code" ] && [ "$asan_exit_code" -ne 0 ]; then
			echo -e "${RED}Test failed due to AddressSanitizer errors${NC}"
			return 1
		else
			echo -e "${GREEN}Test passed${NC}"
			return 0
		fi
	else
		echo -e "${RED}Test failed${NC}"
		echo -e "-> Expected output:\n$expected"
		echo -e "-> Actual output:\n$output"
		return 1
	fi
}

# Function to build the command
build_command() {
	local num_inputs=$1
	shift
	local cmd=$1
	shift
	local option=$1
	shift
	local value=$1
	shift
	local inputs=()
	local files=()
	local is_file=false

	for arg in "$@"; do
		if [ "$is_file" = false ]; then
			inputs+=("$arg")
			if [ "${#inputs[@]}" -eq "$num_inputs" ]; then
				is_file=true
			fi
		else
			files+=("$arg")
		fi
	done

	local command="("
	for input in "${inputs[@]}"; do
		command+="echo \"$input\"; "
	done
	command+=") | $cmd $option $value"
	for file in "${files[@]}"; do
		command+=" $file"
	done
	echo "$command"
}

# Function to run a test with stdin and check the result
run_test_with_inputs() {
	local num_inputs=$1
	shift
	local description=$1
	shift
	local option=$1
	shift
	local value=$1
	shift
	local inputs=()
	for ((i=0; i<num_inputs; i++)); do
		inputs+=("$1")
		shift
	done
	local files=("$@")

	echo "$separator"

	command=$(build_command "$num_inputs" "PROGRAM" "$option" "$value" "${inputs[@]}" "${files[@]}")
	echo "$> $command | cat -e"
	output=$(eval "$(echo "$command" | sed 's/PROGRAM/.\/ft_tail/')" 2>&1)

	command=$(build_command "$num_inputs" "tail" "$option" "$value" "${inputs[@]}" "${files[@]}")
	expected=$(eval "$command" 2>&1)

	expected=$(echo "$expected" | cat -e | sed 's/^tail/PROGRAM/')
	output=$(echo "$output" | cat -e | sed 's/^\.\/ft_tail/PROGRAM/')

	if [ "$output" == "$expected" ]; then
		echo -e "${GREEN}Test passed${NC}"
		return 0
	else
		echo -e "${RED}Test failed${NC}"
		echo -e "-> Expected output:\n$expected"
		echo -e "-> Actual output:\n$output"
		return 1
	fi
}

# Create test files and run tests
create_files
all_tests_passed=true

# Basic tests
run_test "Simple text file" "-c" "5" "simple.txt" || all_tests_passed=false
run_test "Empty file" "-c" "5" "empty.txt" || all_tests_passed=false
run_test "Binary file" "-c" "5" "binary.dat" || all_tests_passed=false
run_test "Large file" "-c" "5" "large.txt" || all_tests_passed=false
run_test "Special characters file" "-c" "5" "special_chars.txt" || all_tests_passed=false

# Multiple files tests
run_test "Multiple files" "-c" "5" "simple.txt" "empty.txt" || all_tests_passed=false
run_test "Empty file with -c 0" "-c" "0" "empty.txt" || all_tests_passed=false
run_test "Large byte count" "-c" "100" "simple.txt" || all_tests_passed=false

# Error cases
run_test "Restricted access file" "-c" "5" "restricted.txt" || all_tests_passed=false
run_test "Non-existent file" "-c" "5" "non_existent.txt" || all_tests_passed=false
run_test "No space in option" "-c5" "simple.txt" || all_tests_passed=false
run_test "Invalid byte count" "-c" "5p" "simple.txt" || all_tests_passed=false

# Stdin tests
run_test_with_inputs 1 "Simple stdin" "-c" "5" "Hello from stdin!" || all_tests_passed=false
run_test_with_inputs 1 "Stdin with files" "-c" "5" "Hello from stdin!" "-" "simple.txt" "empty.txt" || all_tests_passed=false
run_test_with_inputs 2 "Complex stdin case" "-c" "5" "input1" "input2" "non_existent.txt" "-" "simple.txt" "-" "empty.txt" || all_tests_passed=false

# Final result
echo "$separator"
if $all_tests_passed; then
	echo -e "${GREEN}All tests passed: OK${NC}"
else
	echo -e "${RED}Some tests failed: KO${NC}"
fi
echo "$separator"

# Cleanup
make fclean > /dev/null
chmod 644 restricted.txt
rm -f simple.txt empty.txt binary.dat large.txt special_chars.txt restricted.txt .asan_enabled