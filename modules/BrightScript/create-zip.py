#!/usr/bin/env python3


def main():
	import argparse
	import zipfile
	import glob
	import os.path

	parser = argparse.ArgumentParser()
	parser.add_argument('--output', required=True)
	parser.add_argument('--package-dir', required=True)
	args = parser.parse_args()

	files = glob.glob(f'{args.package_dir}/**', recursive=True)
#	print(files)

	tmp_zip_file = f'{args.output}.tmp'

	with zipfile.ZipFile(tmp_zip_file, 'w') as z:
		for file in files:
			if os.path.isfile(file):
				if file.lower().endswith('.png'):
					ctype = zipfile.ZIP_STORED
					clevel = 0
				else:
					ctype = zipfile.ZIP_DEFLATED
					clevel = 9
			elif os.path.isdir(file):
				ctype = None
				clevel = None
			else:
				continue
			arc_file = os.path.relpath(file, args.package_dir)
			z.write(file, arcname=arc_file, compress_type=ctype, compresslevel=clevel)

	os.rename(tmp_zip_file, f'{args.output}')

if __name__ == '__main__':
	main()
