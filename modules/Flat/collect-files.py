#!/usr/bin/python3

import argparse
import glob
import os.path
import io
import sys


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument('output')
	parser.add_argument('--paths', nargs='*', default=[])
	parser.add_argument('--depend-on-files', dest='dependOnFiles', action='store_true')
	parser.add_argument('--relative')
	parser.add_argument('--prepend-dir', dest='prependDir', action='store_true')
	parser.add_argument('--exclude', nargs='*')
	args = parser.parse_args()

	update = False

	if args.dependOnFiles:
		try:
			outputTime = os.path.getmtime(args.output)
		except OSError:
			update = True

	excludes = set()

	def add_exclude(path):
		nonlocal excludes
		excludes.add(path)

	for path in args.exclude:
		f = glob.glob(path, recursive=True)
		if not f:
			if os.path.isfile(path):
				add_exclude(path)
		else:
			for x in f:
				if os.path.isfile(x):
					add_exclude(x)

	files = []

	def add_file(path):
		nonlocal excludes
		nonlocal files
		if path in excludes: return
		files.append(path)

	for path in args.paths:
		f = glob.glob(path, recursive=True)
		if not f:
			if os.path.isfile(path):
				add_file(path)
		else:
			for x in f:
				if os.path.isfile(x):
					add_file(x)

	buffer = io.StringIO()
	for file in files:
		if args.relative:
			file = os.path.relpath(file, args.relative)
		if args.prependDir:
			buffer.write(args.relative)
			buffer.write(':')
		buffer.write(file)
		buffer.write('\n')
	newBuffer = buffer.getvalue()

	if not update:
		try:
			with open(args.output, 'r') as f:
				previousBuffer = f.read()
				if previousBuffer != newBuffer:
					update = True
		except:
			update = True

	if args.dependOnFiles and not update:
		for file in files:
			file_time = os.path.getmtime(file)
			if file_time > outputTime:
				update = True
				break

	if update:
		with open(args.output, 'w') as f:
			f.write(buffer.getvalue())


if __name__ == '__main__':
	main()
