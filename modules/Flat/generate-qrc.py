
import argparse
import io
import os.path

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('qrc')
	parser.add_argument('files')
	parser.add_argument('path')
	parser.add_argument('prefix')
	args = parser.parse_args()

	buffer = io.StringIO()

	buffer.write('<RCC>\n')
	buffer.write('\t<qresource{0}>\n'.format(' prefix="' + args.prefix + '"' if args.prefix else ''))

	with open(args.files, 'r') as f:
		for file in f:
			relpath = os.path.relpath(file, args.path).strip()
			abspath = file.strip()
			buffer.write('\t\t<file alias="{relpath}">{abspath}</file>\n'.format(relpath=relpath, abspath=abspath))

	buffer.write('\t</qresource>\n')
	buffer.write('</RCC>\n')

	with open(args.qrc, 'w') as f:
		f.write(buffer.getvalue())
