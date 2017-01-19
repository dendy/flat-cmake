
import argparse
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True)
parser.add_argument('--compiler', required=True)
parser.add_argument('--pch-file', dest='pch_file', required=True)
parser.add_argument('--flags-file', dest='flags_file', required=True)
args = parser.parse_args()

with open(args.flags_file, 'r') as f:
	pch_args = f.read(None).splitlines()

make_deps_file = args.output + '.make'

subprocess.run([args.compiler, *pch_args, '-x', 'c++-header', '-c', args.pch_file, '-MM', '-o', make_deps_file], check=True)

with open(args.output, 'w') as of:
	with open(make_deps_file, 'r') as f:
		f.readline()
		for line in f:
			line = line.strip()
			if line.endswith('\\'):
				line = line[:-1]
			line = line.strip()
			of.write(line)
			of.write('\n')
