
import argparse
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True)
parser.add_argument('--compiler', required=True)
parser.add_argument('--pch-file', dest='pch_file', required=True)
parser.add_argument('--flags-file', dest='flags_file', required=True)
parser.add_argument('--compile-cli', dest='compile_cli', required=True)
args = parser.parse_args()

with open(args.flags_file, 'r') as f:
	pch_args = f.read(None).splitlines()

make_deps_file = args.output + '.make'

#<CMAKE_CXX_COMPILER> <DEFINES> <INCLUDES> <FLAGS> -UFLAT_DEBUG_DISABLE_MACROS -o <OBJECT> -c <SOURCE>

cli_values = {
	'<CMAKE_CXX_COMPILER>': [args.compiler],
	'<DEFINES>': None,
	'<INCLUDES>': None,
	'<FLAGS>': pch_args + ['-UFLAT_DEBUG_DISABLE_MACROS', '-x', 'c++-header', '-MM'],
	'<OBJECT>': [make_deps_file],
	'<SOURCE>': [args.pch_file]
}

cli = [i for arg in [cli_values.get(arg, [arg]) for arg in args.compile_cli.split()] if arg != None for i in arg]

subprocess.run(cli, check=True)

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
