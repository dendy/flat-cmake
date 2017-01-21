
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
parser.add_argument("--compile-cli", dest='compile_cli', required=True)
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

cli_values = {
	'<CMAKE_CXX_COMPILER>': None,
	'<DEFINES>': None,
	'<INCLUDES>': None,
	'<FLAGS>': None,
	'<OBJECT>': args.output,
	'<SOURCE>': args.pch
}

cli = [arg for arg in [cli_values.get(arg, arg) for arg in args.compile_cli.split()] if arg != None]

subprocess.run([args.compiler, '-x', 'c++-header', *pch_args] + cli, check=True)
