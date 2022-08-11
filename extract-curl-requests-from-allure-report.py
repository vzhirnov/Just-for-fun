#!/usr/bin/python

import os

CURL = 'curl'

print('#'*100)
print("#"*29, 'EXTRACT CURL REQUESTS FROM ALLURE REPORT', "#"*29)
print('#'*100)

search_path = input("Enter directory path to search: ") or '.'
file_type = input("File Type: ") or '.txt'
search_str = input("What string patterns should be contained in the request? ") or ''
search_str = search_str.split()

results_file_name = input("Enter output file for curls: ") or 'curls.txt'
should_print_to_stdout = input("Should I print all found curls to stdout? [Y/n]: ") or True

if not (search_path.endswith("/") or search_path.endswith("\\")):
    search_path = search_path + "/"
if not os.path.exists(search_path):
    search_path = "."

final_list = []

with open(search_path + results_file_name, 'w') as file_with_results:
    for file_name in os.listdir(path=search_path):
        if file_name.endswith(file_type):
            with open(search_path + file_name) as fo:
                line = fo.readline()
                if line.startswith(CURL) and all([item in line for item in search_str]):
                    file_with_results.write(line + '\n\n')

                    if should_print_to_stdout:
                        print(line, end='\n\n')
