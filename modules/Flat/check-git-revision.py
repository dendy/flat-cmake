#!/usr/bin/python3

import sys
import subprocess
import argparse
import os.path

class Git:
	def __init__(self, path):
		self.path = path

	def exec(self, *args):
		try:
			return subprocess.run(['git', '--no-pager'] + [x for x in args],
				stdout=subprocess.PIPE, universal_newlines=True, check=True, cwd=self.path).stdout.strip()
		except:
			print('git error for:', self.path, file=sys.stderr)
			raise

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('gitDir')
	parser.add_argument('targetFile')
	parser.add_argument('--no-dirty', dest='dirty', action='store_false')
	args = parser.parse_args()

	git = Git(args.gitDir)

	stashRevision = git.exec('stash', 'create') if args.dirty else None
	revision = stashRevision if stashRevision else 'HEAD'

	tree = git.exec('show', '-s', '--format=%T', revision)

	previousTree = None
	try:
		with open(args.targetFile, 'r', newline='') as f:
			previousTree = f.readline().strip()
	except:
		pass

	if tree != previousTree:
		os.makedirs(os.path.dirname(args.targetFile), exist_ok=True)
		with open(args.targetFile, 'w', newline='\n') as f:
			f.write(tree)
			f.write('\n')
