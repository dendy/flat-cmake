#!/usr/bin/env python3


import argparse
import os.path


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument('--output', required=True)
	parser.add_argument('--source-dir', required=True)
	parser.add_argument('--files', nargs='*', default=[])
	args = parser.parse_args()

	os.makedirs(os.path.dirname(args.output), exist_ok=True)

	with open(args.output, 'w') as f:
		for file in args.files:
			path = os.path.relpath(file, args.source_dir)
			if os.path.isabs(path) or path.startswith('../'):
				raise AttributeError(f'Invalid file: {file} source dir: {args.source_dir}')
			print(f'{path}', file=f, end='\n')


if __name__ == '__main__':
	main()
