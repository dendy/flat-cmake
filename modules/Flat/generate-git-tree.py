#!/usr/bin/python3

import sys
import subprocess
import argparse
import os.path
import tempfile
import shutil

class Git:
	def __init__(self, path, env=None):
		self.path = path
		self.env = env

	def exec(self, *args):
		try:
			return subprocess.run(['git', '--no-pager'] + [x for x in args],
				stdout=subprocess.PIPE, universal_newlines=True, check=True,
				cwd=self.path, env=self.env).stdout.strip()
		except:
			print('git error for:', self.path, file=sys.stderr)
			raise

	def ok(self, *args):
		return subprocess.run(['git', '--no-pager'] + [x for x in args],
			stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False,
			cwd=self.path, env=self.env).returncode == 0

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--git-dir')
	parser.add_argument('--output')
	parser.add_argument('--no-dirty', dest='dirty', action='store_false')
	parser.add_argument('--no-untracked', dest='untracked', action='store_false')
	args = parser.parse_args()

	git = Git(args.git_dir)

	if not args.dirty:
		tree = git.exec('rev-parse', 'HEAD^{tree}')
	else:
		tmp_dir = None

		should_copy_index = False

		tracked_changes = git.exec('diff-files', '--name-only').splitlines()

		if tracked_changes:
			# has changes in tracked files
			should_copy_index = True

		if args.untracked:
			# check untracked files presence
			untracked_changes = git.exec('ls-files', '-o').splitlines()

			if not should_copy_index:
				should_copy_index = bool(untracked_changes)

		if not should_copy_index:
			# take tree directly from .git/index
			index_git =  git
		else:
			# copy original index file into temporary location to add tracked/untracked files
			# and get tree without affecting original .git/index
			this_index_file = os.path.join(git.path, git.exec('rev-parse', '--git-path', 'index'))

			tmp_dir = tempfile.TemporaryDirectory()
			index_file = os.path.join(tmp_dir.name, 'index')
			shutil.copyfile(this_index_file, index_file)

			# index_git is the same as git, but will use temporary index instead
			env = os.environ.copy()
			env['GIT_INDEX_FILE'] = index_file
			index_git = Git(git.path, env)

			if tracked_changes:
				# add tracked files into index
				index_git.exec('update-index', '--add', '--remove', '--', *tracked_changes)

			if args.untracked and untracked_changes:
				# add untracked files into index
				index_git.exec('update-index', '--add', '--', *untracked_changes)

		tree = index_git.exec('write-tree')

	with open(args.output, 'w') as f:
		print(tree, file=f)
