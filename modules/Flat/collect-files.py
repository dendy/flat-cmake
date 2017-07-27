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
	parser.add_argument('--depend-on-files', dest='dependOnFiles', action='store_true')
	args = parser.parse_args()

	update = False

	if args.dependOnFiles:
		try:
			outputTime = os.path.getctime(args.output)
		except OSError:
			update = True

	files = []
	for path in args.paths:
		f = glob.glob(path, recursive=True)
		if not f:
			if os.path.isfile(path):
				files.append(path)
		else:
			files += [x for x in f if os.path.isfile(x)]

	buffer = io.StringIO()
	for file in files:
		buffer.write(file)
		buffer.write('\n')
	newBuffer = buffer.getvalue()

	if not update:
		try:
			with open(args.output, 'r') as f:
				previousBuffer = f.read()
				if previousBuffer != newBuffer:
					update = true
		except:
			pass

	if args.dependOnFiles and not update:
		for file in files:
			if os.path.getctime(file) > outputTime:
				update = True
				break

	if update:
		with open(args.output, 'w') as f:
			f.write(buffer.getvalue())
