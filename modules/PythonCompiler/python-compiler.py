#! /usr/bin/python3 -B

import py_compile
import sys
import os.path
import argparse


def main():
	argParser = argparse.ArgumentParser()
	argParser.add_argument("input_file", help = "Source py-file", type = str)
	argParser.add_argument("-o", "--output", help = "Destination pyc-file", type = str)
	args = argParser.parse_args()

	try:
		py_compile.compile(args.input_file, args.output, os.path.abspath( args.input_file ), True, -1)
	except py_compile.PyCompileError as err:
		print(err.file, ":", err.exc_value.lineno, ":", err.exc_value.offset, ": error: ", err.exc_type_name, \
			"\n\n", err.msg, \
			sep = '', file = sys.stderr)
		exit(1)


main()
