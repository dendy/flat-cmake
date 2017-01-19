
import argparse
import subprocess
import sys
import os.path

parser = argparse.ArgumentParser()
parser.add_argument('--deps', required=True)
parser.add_argument('--pch', required=True)
parser.add_argument('--target', required=True)
args = parser.parse_args()

getmtime = os.path.getmtime

def need_update():
	pch_mtime = getmtime(args.pch)

	try:
		deps_mtime = getmtime(args.deps)
	except FileNotFoundError:
		return True
	if pch_mtime > deps_mtime:
		return True

	with open(args.deps, 'r') as f:
		for line in f:
			try:
				dep_mtime = getmtime(line.strip())
			except FileNotFoundError:
				return True
			if dep_mtime > deps_mtime:
				return True

	return False

if need_update():
	with open(args.target, 'w'):
		pass
