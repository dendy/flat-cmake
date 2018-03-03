#!/usr/bin/env python3

import argparse
import glob
import os.path
import io

def exec():
	parser = argparse.ArgumentParser()
	parser.add_argument('--paths', nargs='*')
	parser.add_argument('--output', required=True)
	args = parser.parse_args()

	files = []

	for path in args.paths:
		foundFiles = glob.glob(path, recursive=True)
		if foundFiles:
			files += foundFiles
		elif os.path.isfile(path):
			files.append(path)
	files = sorted(files)

	filesString = io.StringIO()
	for file in files:
		filesString.write(file)
		filesString.write('\n')

	try:
		with open(args.output, 'r') as f:
			if f.read() == filesString.getvalue():
				return
	except FileNotFoundError:
		pass

	with open(args.output, 'w') as f:
		f.write(filesString.getvalue())

if __name__ == '__main__':
	exec()
