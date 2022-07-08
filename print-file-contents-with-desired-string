"""
In the given directory, print the contents of files if they contain the desired string
"""

import os

search_path = input("Enter directory path to search : ")
file_type = input("File Type : ")
search_str = input("Enter the search string : ")

if not (search_path.endswith("/") or search_path.endswith("\\")):
  search_path = search_path + "/"

if not os.path.exists(search_path):
  search_path ="."

for fname in os.listdir(path=search_path):

  if fname.endswith(file_type):
    fo = open(search_path + fname)

    line = fo.readline()

    if line.startswith(search_str) and 'hint/create' in line:
      print(line, "\n", sep="\n\n")

    fo.close()
