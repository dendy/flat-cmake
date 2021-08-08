#!/usr/bin/env python3


def main():
	import argparse
	import glob
	import os.path
	import shutil
	import time

	parser = argparse.ArgumentParser()
	parser.add_argument('--output', required=True)
	parser.add_argument('--libs', nargs='*', required=True)
	parser.add_argument('--files', nargs='*', required=True)
	parser.add_argument('--update-done-file', required=True)

	args = parser.parse_args()

#	print(f'{args.libs} -> {args.files}')

	if len(args.libs) != len(args.files):
		raise AttributeError('usage')

	def collect_target_files():
		nonlocal args
		output_dir = args.output
		files = set(glob.glob(f'{output_dir}/**', recursive=True))
		ignored = glob.glob(f'{output_dir}/*', recursive=True)
#		print(f'of={files};ig={ignored};')
		ignored = [f for f in ignored if os.path.isfile(f)]
		files -= set(ignored)
#		print(f'dif={files};')
		return set([os.path.relpath(f, output_dir) for f in files])
	#	print(f'rof={target_files};')

	target_files = collect_target_files()

	source_files = dict()

	for i in range(len(args.libs)):
		lib = args.libs[i]
		files = args.files[i]
#		print(f'{lib} -> {files}')

		with open(files, 'r') as f:
			for line in f:
				line = line.strip()
				source_files[line] = lib

	def check_update(file, abs_target_file, abs_source_file):
		nonlocal target_files
		try:
			target_files.remove(file)
		except KeyError:
			return True
		target_time = os.path.getmtime(abs_target_file)
		source_time = os.path.getmtime(abs_source_file)
#		print(f'{target_time} {source_time}')
		return source_time > target_time

	def copy_file(source_file, target_file):
		target_dir = os.path.dirname(target_file)
		os.makedirs(target_dir, exist_ok=True)
		try:
			os.link(source_file, target_file)
		except OSError:
			shutil.copy2(source_file, target_file)

	updated = False

	for file, lib in source_files.items():
#		print(f'sf={file} {lib}')
		abs_source_file = os.path.join(lib, file)
		abs_target_file = os.path.join(args.output, file)
		if check_update(file, abs_target_file, abs_source_file):
			updated = True
			copy_file(abs_source_file, abs_target_file)
			print(f'Copied: {abs_source_file} -> {abs_target_file}')

	remaining_files = sorted(list(target_files), reverse=True)
#	print(f'remains: {target_files} {remaining_files}')
	for file in remaining_files:
		abs_file = os.path.join(args.output, file)
		if os.path.isfile(abs_file):
			os.remove(abs_file)
			updated = True
			print(f'Removed file: {abs_file}')
		elif os.path.isdir(abs_file):
			try:
				os.rmdir(abs_file)
				updated = True
				print(f'Removed dir: {abs_file}')
			except FileNotFoundError:
				pass
			except OSError:
				pass
		else:
			raise OSError(f'Invalid file: {abs_file}')

	if updated:
		with open(args.update_done_file, 'w') as f:
			pass


if __name__ == '__main__':
	main()
