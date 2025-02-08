#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Run norminette check
echo "Running norminette check..."
output=$(norminette 2>&1)
if [ $? -ne 0 ]; then
	echo "$output" | grep -E --color=always "Error|Warning|Norme"
	echo -e "${RED}Norminette check failed${NC}"
#	exit 1
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
	# ls -l > /dev/null
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
longest_test="$> (echo \"first input\"; echo \"second input\"; ) | ./ft_cat simple.txt - - restricted.txt"
# Add some padding for better visuals and generate the separator
separator=$(generate_separator $((${#longest_test} + 2)))

# Function to run a test and check the result
run_test() {
	local description=$1
	shift
	local files=("$@")

	echo "$separator"
#	echo "$description"
	echo "$> ./ft_cat ${files[*]}"

	expected=$(cat "${files[@]}" 2>&1)
	output=$(./ft_cat "${files[@]}" 2>&1)
	# Normalize program names in the output
	expected=$(echo "$expected" | cat -e | sed 's/^cat/PROGRAM/')
	output=$(echo "$output" | cat -e | sed 's/^ft_cat/PROGRAM/')

	if [ "$output" == "$expected" ]; then
		echo -e "${GREEN}Test passed${NC}"
		#echo -e "-> Actual output:\n$output"
		return 0
	else
		echo -e "${RED}Test failed${NC}"
		echo -e "-> Expected output:\n$expected"
		echo -e "-> Actual output:\n$output"
		return 1
	fi
}

# Function to build the command
build_command() {
	local cmd=$1
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
	command+=") | $cmd ${files[*]}"
	echo "$command"
}

run_test_with_inputs() {
	local num_inputs=$1
	shift
	local description=$1
	shift
	local inputs=()
	for ((i=0; i<num_inputs; i++)); do
		inputs+=("$1")
		shift
	done
	local files=("$@")

	echo "$separator"
	#echo "$description"

	command=$(build_command "./ft_cat" "${inputs[@]}" "${files[@]}")
	echo "$> $command"
	output=$(eval "$command" 2>&1)

	command=$(build_command "cat" "${inputs[@]}" "${files[@]}")
	expected=$(eval "$command" 2>&1)

	expected=$(echo "$expected" | sed 's/^cat/PROGRAM/')
	output=$(echo "$output" | sed 's/^ft_cat/PROGRAM/')

	if [ "$output" == "$expected" ]; then
		echo -e "${GREEN}Test passed${NC}"
		#echo -e "-> Actual output:\n$output"
		return 0
	else
		echo -e "${RED}Test failed${NC}"
		echo -e "-> Expected output:\n$expected"
		echo -e "-> Actual output:\n$output"
		return 1
	fi
}

# Create test files
create_files

# Run tests
all_tests_passed=true

# Test: Simple text file
run_test "Simple text file with content 'Hello, World!'" "simple.txt" || all_tests_passed=false
# Test: Empty file
run_test "Empty file with no content" "empty.txt" || all_tests_passed=false
# Test: Special characters file
run_test "File with special characters" "special_chars.txt" || all_tests_passed=false
# Test: Multiple files
run_test "Multiple files" "simple.txt" "empty.txt" "special_chars.txt" || all_tests_passed=false
# Test: Binary file
run_test "Binary file" "binary.dat" || all_tests_passed=false
# Test: Large file
run_test "Large file" "large.txt" || all_tests_passed=false
# Test: Restricted access file
run_test "Restricted access file" "restricted.txt" || all_tests_passed=false
# Test: Non-existent file
run_test "Non-existent file" "non_existent.txt" || all_tests_passed=false

# STDIN
# Test: Stdin with simple text
run_test_with_inputs 1 "Stdin with simple text" "Hello from stdin!" || all_tests_passed=false
# Test: Mixed files and stdin
run_test_with_inputs 2 "Mixed files and stdin" "first input" "second input" "simple.txt" "-" "-" "restricted.txt" || all_tests_passed=false

# Final result
echo "$separator"
if $all_tests_passed; then
	echo -e "${GREEN}All tests passed: OK${NC}"
else
	echo -e "${RED}Some tests failed: KO${NC}"
fi
echo "$separator"

# Clean up compiled files
make fclean > /dev/null
chmod 644 restricted.txt
rm simple.txt empty.txt binary.dat large.txt special_chars.txt restricted.txt
