#!/usr/bin/env python3


class Manifest:
	def __init__(self, filePath, entries):
		self.filePath = filePath
		self.entries = entries


def parse_manifest(filePath):
	with open(filePath, 'r') as f:
		entries = dict()

		lineNumber = 0

		for line in f:
			lineNumber += 1
			line = line.strip()
			if not line: continue
			if line.startswith('#'): continue
			equalPos = line.find('=')
			if equalPos == -1 or equalPos == 0:
				raise AttributeError(f'Invalid manifest line: {filePath}:{lineNumber}: {line}')
			key = line[:equalPos].lower()
			value = line[equalPos+1:]
			if key in entries:
				raise AttributeError(f'Duplicated manifest key: {filePath}:{lineNumber}: {line}')
			entries[key] = value

		return Manifest(filePath, entries)


def main():
	import argparse

	parser = argparse.ArgumentParser()
	parser.add_argument('--output', required=True)
	parser.add_argument('--manifests', nargs='*', required=True)

	args = parser.parse_args()

	if not args.manifests:
		raise AttributeError('empty manifests')

	manifests = []

	for manifestFilePath in args.manifests:
		manifest = parse_manifest(manifestFilePath)
		manifests.append(manifest)

	with open(args.output, 'w') as f:
		entries = dict()
		for manifest in manifests:
			entries.update(manifest.entries)
		for key in sorted(entries.keys()):
			print(f'{key}={entries[key]}', file=f, end='\n')


if __name__ == '__main__':
	main()
