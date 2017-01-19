
import argparse
import subprocess
import sys
import collections

parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True)
parser.add_argument('--compiler-id', dest='compiler_id', required=True)
parser.add_argument('--compiler', required=True)
parser.add_argument('--pch', required=True)
parser.add_argument('--flags-file', dest='flags_file', required=True)
args = parser.parse_args()

def filter(s):
	return [v for v in [v.strip() for v in s.split(';')] if v]

if args.compiler_id == 'GNU' or args.compiler_id == 'Clang':
	pass
else:
	print('Invalid compiler id: ' + args.compiler_id, file=sys.stderr)
	sys.exit(1)

with open(args.flags_file, 'r') as f:
	pch_args = f.read(None).splitlines()

subprocess.run([args.compiler, *pch_args, '-x', 'c++-header', '-c', args.pch, '-o', args.output], check=True)
