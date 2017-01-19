
import argparse
import subprocess
import sys
import collections

parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True)
parser.add_argument('--compiler-id', dest='compiler_id', required=True)
parser.add_argument('--include-dirs', dest='include_dirs', required=True)
parser.add_argument('--compile-options', dest='compile_options', required=True)
parser.add_argument('--compile-flags', dest='compile_flags', required=True)
parser.add_argument('--compile-definitions', dest='compile_definitions', required=True)
parser.add_argument('--pic', required=True)
parser.add_argument('--type', required=True)
parser.add_argument('--pic-flags', dest='pic_flags', required=True)
parser.add_argument('--pie-flags', dest='pie_flags', required=True)
parser.add_argument('--extra-flags', dest='extra_flags', required=True);
parser.add_argument('--pch', required=True)
args = parser.parse_args()

def filter(s):
	return [v for v in [v.strip() for v in s.split(';')] if v]

pch_args = []
pch_args += ['-I' + dir for dir in filter(args.include_dirs)]
pch_args += filter(args.compile_options)
pch_args += ['-D' + d for d in filter(args.compile_definitions)]
pch_args += filter(args.compile_options)
pch_args += filter(args.extra_flags)
if args.pic == '1':
	pch_args += filter(args.pie_flags if args.type == 'EXECUTABLE' else args.pic_flags)

pch_args = list(collections.OrderedDict.fromkeys(pch_args))

if args.compiler_id == 'GNU' or args.compiler_id == 'Clang':
	pass
else:
	print('Invalid compiler id: ' + args.compiler_id, file=sys.stderr)
	sys.exit(1)

with open(args.output, 'w') as f:
	f.write('\n'.join(pch_args))
	f.write('\n')
