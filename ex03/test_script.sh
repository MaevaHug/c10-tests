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
#	exit 1
else
	echo -e "${GREEN}Norminette check passed${NC}"
fi

# Compile the files using make
echo "Compiling the program..."
make > /dev/null 2> make_errors.log
#make sanitize > /dev/null 2> make_errors.log
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
	yes "A" | head -c 48 > identical_chars.txt
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
longest_test="$> ./ft_hexdump -C simple.txt restricted.txt empty.txt | cat -e"
# Add some padding for better visuals and generate the separator
separator=$(generate_separator $((${#longest_test} + 2)))

# Function to run a test and check the result
run_test() {
	local description=$1
	local option=$2
	shift 2
	local files=("$@")

	echo "$separator"
	#echo "$description"

	if [ "$option" == "-C" ]; then
		echo "$> ./ft_hexdump -C ${files[*]} | cat -e"
		expected=$(hexdump -C "${files[@]}" 2>&1 | cat -e | sed 's/hexdump/PROGRAM/')
		output=$(./ft_hexdump -C "${files[@]}" 2>&1 | cat -e | sed 's/ft_hexdump/PROGRAM/')
	else
		echo "$> ./ft_hexdump ${files[*]} | cat -e"
		expected=$(hexdump "${files[@]}" 2>&1 | cat -e | sed 's/hexdump/PROGRAM/')
		output=$(./ft_hexdump "${files[@]}" 2>&1 | cat -e | sed 's/ft_hexdump/PROGRAM/')
	fi

	if [ "$output" == "$expected" ]; then
		if [ -n "$ASAN_ENABLED" ] && [ "$ASAN_ENABLED" -eq 1 ] && [ -n "$asan_exit_code" ] && [ "$asan_exit_code" -ne 0 ]; then
			echo -e "${RED}Test failed due to AddressSanitizer errors${NC}"
			return 1
		else
			echo -e "${GREEN}Test passed${NC}"
			#echo -e "-> Actual output:\n$output"
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
	local cmd=$1
	local option=$2
	local input=$3

	if [ "$option" == "-C" ]; then
		echo "echo \"$input\" | $cmd -C"
	else
		echo "echo \"$input\" | $cmd"
	fi
}

# Function to run a test with stdin and check the result
run_stdin_test() {
	local description=$1
	local option=$2
	local input=$3

	echo "$separator"
	#echo "$description"
	
	command=$(build_command "hexdump" "$option" "$input")
	expected=$(eval "$command" 2>&1 | cat -e | sed 's/hexdump/PROGRAM/')

	command=$(build_command "./ft_hexdump" "$option" "$input")
	echo "$> $command | cat -e"
	output=$(eval "$command" 2>&1 | cat -e | sed 's/ft_hexdump/PROGRAM/')

	if [ "$output" == "$expected" ]; then
		if [ -n "$ASAN_ENABLED" ] && [ "$ASAN_ENABLED" -eq 1 ] && [ -n "$asan_exit_code" ] && [ "$asan_exit_code" -ne 0 ]; then
			echo -e "${RED}Test failed due to AddressSanitizer errors${NC}"
			return 1
		else
			echo -e "${GREEN}Test passed${NC}"
			#echo -e "-> Actual output:\n$output"
			return 0
		fi
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

# Tests with -C option
# Test: Simple text file
run_test "Simple text file with content 'Hello, World!'" "-C" "simple.txt" || all_tests_passed=false
# Test: Empty file
run_test "Empty file with no content" "-C" "empty.txt" || all_tests_passed=false
# Test: Binary file
run_test "Binary file" "-C" "binary.dat" || all_tests_passed=false
# Test: Large file
#run_test "Large file" "-C" "large.txt" || all_tests_passed=false
# Test: Special characters file
run_test "File with special characters" "-C" "special_chars.txt" || all_tests_passed=false
# Test: File with identical characters
run_test "File with identical characters" "-C" "identical_chars.txt" || all_tests_passed=false
# Test: Restricted access file
run_test "Restricted access file" "-C" "restricted.txt" || all_tests_passed=false
# Test: Non-existent file
run_test "Non-existent file" "-C" "non_existent.txt" || all_tests_passed=false
# Test: Multiple files
run_test "Multiple files (simple.txt and empty.txt)" "-C" "simple.txt" "empty.txt" || all_tests_passed=false
# Test: Multiple files with an error
run_test "Multiple files with an error (simple.txt, restricted.txt and empty.txt)" "-C" "simple.txt" "restricted.txt" "empty.txt" || all_tests_passed=false


# Tests without -C option
# Test: Simple text file without -C option
run_test "Simple text file without -C option" "" "simple.txt" || all_tests_passed=false
# Test: Empty file without -C option
run_test "Empty file without -C option" "" "empty.txt" || all_tests_passed=false
# Test: Binary file without -C option
run_test "Binary file without -C option" "" "binary.dat" || all_tests_passed=false
# Test: Multiple files without -C option
run_test "Multiple files (simple.txt and empty.txt) without -C option" "" "simple.txt" "empty.txt" || all_tests_passed=false
# Test: Multiple files with an error without -C option
run_test "Multiple files with an error (simple.txt, restricted.txt and empty.txt) without -C option" "" "simple.txt" "restricted.txt" "empty.txt" || all_tests_passed=false

# Tests with stdin
# Test: Stdin with simple text
run_stdin_test "Stdin with simple text" "-C" "Hello from stdin!" || all_tests_passed=false
# Test: Stdin with simple text without -C option
run_stdin_test "Stdin with simple text without -C option" "" "Hello from stdin!" || all_tests_passed=false

# Final result
echo "$separator"
if $all_tests_passed; then
	echo -e "${GREEN}All tests passed: OK${NC}"
else
	echo -e "${RED}Some tests failed: KO${NC}"
fi
echo "$separator"

# Clean up compiled files
make fclean > /dev/null 2>&1
chmod 644 restricted.txt
rm simple.txt empty.txt binary.dat large.txt special_chars.txt restricted.txt identical_chars.txt

if [ -f .asan_enabled ]; then
	rm -f .asan_enabled
fi