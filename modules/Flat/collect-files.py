#!/usr/bin/python3

import argparse
import glob
import os.path
import io
import sys

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('output')
	parser.add_argument('--paths', nargs='*', default=[])
	args = parser.parse_args()

	files = []
	for path in args.paths:
		f = glob.glob(path, recursive=True)
		if not f:
			if os.path.isfile(path):
				files.append(path)
		else:
			files += f

	buffer = io.StringIO()
	for file in files:
		buffer.write(file)
		buffer.write('\n')

	previousBuffer = None
	try:
		with open(args.output, 'r') as f:
			previousBuffer = f.read()
	except:
		pass

	if previousBuffer != buffer.getvalue():
		with open(args.output, 'w') as f:
			f.write(buffer.getvalue())
