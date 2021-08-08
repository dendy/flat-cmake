
import argparse
import os.path
import sys
import shutil

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--source', required=True)
	parser.add_argument('--destination', required=True)
	parser.add_argument('--dir', required=True)
	args = parser.parse_args()

	def read_files(file):
		with open(file, 'r') as f:
			return { tuple(line.split(':', maxsplit=1)) for line in set(f.read().splitlines()) }

	files = read_files(args.source)

	try:
		previousFiles = read_files(args.destination)
	except OSError:
		previousFiles = set()

	# delete missing files
	for dir, file in previousFiles - files:
		os.remove(os.path.join(args.dir, file))

	# copy newer files
	for dir, file in files:
		sourceFile = os.path.join(dir, file)
		destinationFile = os.path.join(args.dir, file)
		if not os.path.isfile(destinationFile) \
				or os.path.getmtime(sourceFile) > os.path.getmtime(destinationFile):
			os.makedirs(os.path.dirname(destinationFile), exist_ok=True)
			shutil.copyfile(sourceFile, destinationFile, follow_symlinks=True)

	with open(args.destination, 'w') as of:
		for dir, file in files:
			of.write('{}:{}\n'.format(dir, file))
