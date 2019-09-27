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
	parser.add_argument('--files', required=True)
	parser.add_argument('--verbose', default=False)
	args = parser.parse_args()

	fileSum = open(args.file, 'r').read().strip()

	files = open(args.files, 'r').read().splitlines()

	if fileSum != args.sum:
		print('\n\nVerification failed for target ' + args.name + ', expected sum: ' + fileSum,
				file=sys.stderr)

		if args.doc:
			print('\n' + args.doc.replace('@EXPECTED_SUM@', fileSum), file=sys.stderr)

		if args.gits:
			print('\nLooking for git revisions:', end='', file=sys.stderr)
			foundRevisions = 0

			for git in args.gits:
				dir, rev, good = git.split(':', maxsplit=2)

				allFiles = [os.path.relpath(f, start=dir) for f in files]
				dirFiles = [p for p in allFiles if not p.startswith('..')]

				if dirFiles:
					revisions = subprocess.run(['git', '-C', dir, 'log', '-s', '--format=%H %s',
							rev + '..' + good, '--'] + dirFiles,
							check=True, stdout=subprocess.PIPE, universal_newlines=False).stdout

					# WA: Output might contain invalid CR, use universal_newlines=False and replace
					#     those with empty string instead of new line.
					revisions = revisions.replace(b'\r', b'').decode()

					if revisions:
						if foundRevisions == 0:
							print(file=sys.stderr)

						print('\n' + dir, file=sys.stderr)

						if args.verbose:
							print()
							print('Found files:')
							for dirFile in dirFiles:
								print('    ' + dirFile)

						for revision in revisions.splitlines():
							print('    ' + revision[:100].replace('\n', ' '), file=sys.stderr)
							foundRevisions += 1

			if foundRevisions == 0:
				print(' not found\n')

		sys.exit(1)

	open(args.target, 'w')
