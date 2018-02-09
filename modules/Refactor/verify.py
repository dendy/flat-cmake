#!/usr/bin/env python

import argparse
import sys
import subprocess
import os.path

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--file', required=True)
	parser.add_argument('--sum', required=True)
	parser.add_argument('--target', required=True)
	parser.add_argument('--name', required=True)
	parser.add_argument('--doc', required=True)
	parser.add_argument('--gits', nargs='*')
	parser.add_argument('--paths', nargs='*')
	args = parser.parse_args()

	fileSum = open(args.file, 'r').read().strip()

	if fileSum != args.sum:
		print('Verification failed for target ' + args.name + ', expected sum: ' + fileSum,
				file=sys.stderr)

		if args.doc:
			print('\n' + args.doc, file=sys.stderr)

		if args.gits:
			print('\nLooking for git revisions:', end='', file=sys.stderr)
			foundRevisions = 0

			for git in args.gits:
				dir, rev = git.split(':', maxsplit=1)

				paths = [p for p in [os.path.relpath(p, start=dir) for p in args.paths] \
						if not p.startswith('..')]

				if paths:
					revisions = subprocess.run(['git', '-C', dir, 'log', '-s', '--format=%H %s',
							rev + '..HEAD', '--'] + paths,
							check=True, stdout=subprocess.PIPE, universal_newlines=True).stdout

					if revisions:
						if foundRevisions == 0:
							print(file=sys.stderr)

						print('\n' + dir, file=sys.stderr)
						for revision in revisions.splitlines():
							print('    ' + revision[:100], file=sys.stderr)
							foundRevisions += 1

			if foundRevisions == 0:
				print('not found')

		sys.exit(1)

	open(args.target, 'w')
