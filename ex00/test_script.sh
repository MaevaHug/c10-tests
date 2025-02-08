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
longest_test="$> ./ft_display_file restricted.txt 2> error_output.txt"
# Add some padding for better visuals and generate the separator
separator=$(generate_separator $((${#longest_test} + 2)))

# Function to run a test and check the result
run_test() {
	local file=$1
	local expected=$2

	echo "$separator"
	echo "$> ./ft_display_file $file | cat -e"

	output=$(./ft_display_file "$file" | cat -e 2>&1)

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

# No arguments
echo "$separator"
#echo "Test: No arguments"
echo "$> ./ft_display_file 2> error_output.txt"
./ft_display_file 2> error_output.txt
output=$(cat -e error_output.txt)
expected="File name missing.$"
if [ "$output" == "$expected" ]; then
	echo -e "${GREEN}Test passed${NC}"
	#echo -e "-> Actual output:\n$output"
else
	echo -e "${RED}Test failed${NC}"
	echo -e "-> Expected output:\n$expected"
	echo -e "-> Actual output:\n$output"
	all_tests_passed=false
fi

# Too many arguments
echo "$separator"
#echo "Test: Too many arguments"
echo "$> ./ft_display_file file1 file2 2> error_output.txt"
./ft_display_file file1 file2 2> error_output.txt
output=$(cat -e error_output.txt)
expected="Too many arguments.$"
if [ "$output" == "$expected" ]; then
	echo -e "${GREEN}Test passed${NC}"
	#echo -e "-> Actual output:\n$output"
else
	echo -e "${RED}Test failed${NC}"
	echo -e "-> Expected output:\n$expected"
	echo -e "-> Actual output:\n$output"
	all_tests_passed=false
fi

# Restricted access file
echo "$separator"
#echo "Test: Restricted access file"
echo "$> ./ft_display_file restricted.txt 2> error_output.txt"
./ft_display_file restricted.txt 2> error_output.txt
output=$(cat -e error_output.txt)
expected="Cannot read file.$"
if [ "$output" == "$expected" ]; then
	echo -e "${GREEN}Test passed${NC}"
	#echo -e "-> Actual output:\n$output"
else
	echo -e "${RED}Test failed${NC}"
	echo -e "-> Expected output:\n$expected"
	echo -e "-> Actual output:\n$output"
	all_tests_passed=false
fi

# Simple text file
run_test "simple.txt" "Hello, World!$" || all_tests_passed=false
# Empty file
run_test "empty.txt" "" || all_tests_passed=false

# Binary file → should handle binary files
echo "$separator"
echo "$> ./ft_display_file binary.dat | cat -e"
output=$(./ft_display_file binary.dat | cat -e)
expected="Binary content."
if [ $? -eq 0 ]; then
	echo -e "${GREEN}Test passed${NC}"
	#echo -e "-> Actual output:\n$output"
else
	echo -e "${RED}Test failed${NC}"
	echo -e "-> Expected output:\n$expected"
	echo -e "-> Actual output:\n$output"
	all_tests_passed=false
fi

# Large file
echo "$separator"
echo "$> ./ft_display_file large.txt | cat -e"
output=$(./ft_display_file large.txt | cat -e 2>&1)
if [ $? -eq 0 ]; then
	echo -e "${GREEN}Test passed${NC}"
	#echo -e "-> Actual output:\n$output"
else
	echo -e "${RED}Test failed${NC}"
	echo -e "-> Expected output:\n$expected"
	echo -e "-> Actual output:\n$output"
	all_tests_passed=false
fi

# Special characters file
run_test "special_chars.txt" '!@#$%^&*()_+{}|:"<>?$' || all_tests_passed=false

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
rm simple.txt empty.txt binary.dat large.txt special_chars.txt restricted.txt error_output.txt
