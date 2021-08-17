#!/usr/bin/env python3


import argparse
import os.path
import yaml


class Manifest:
	def __init__(self, filePath, entries):
		self.filePath = filePath
		self.entries = entries


def parse_raw_manifest(filePath):
	entries = dict()

	with open(filePath, 'r') as f:
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


def parse_yaml_manifest(filePath):
	with open(filePath, 'r') as f:
		m = yaml.load(f, Loader=yaml.FullLoader)

	entries = dict()

	def parse_version(k, v):
		nonlocal entries
		nums = v.split('.')
		if len(nums) != 3: raise AttributeError(f'Invalid version: {v}')
		entries['major_version'] = nums[0]
		entries['minor_version'] = nums[1]
		entries['build_version'] = nums[2]

	def parse_default(k, v):
		nonlocal entries
		entries[k] = str(v)

	parsers = dict(
		version=parse_version
	)

	for key, value in m.items():
		parser = parsers.get(key)
		if parser is None:
			parser = parse_default
		parser(key, value)

	return Manifest(filePath, entries)


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument('--output', required=True)
	parser.add_argument('--manifests', nargs='*', required=True)

	args = parser.parse_args()

	if not args.manifests:
		raise AttributeError('empty manifests')

	manifests = []

	for manifestFilePath in args.manifests:
		fileName = os.path.basename(manifestFilePath)
		if fileName.endswith('.yaml'):
			manifest = parse_yaml_manifest(manifestFilePath)
		else:
			manifest = parse_raw_manifest(manifestFilePath)
		manifests.append(manifest)

	with open(args.output, 'w') as f:
		entries = dict()
		for manifest in manifests:
			entries.update(manifest.entries)
		for key in sorted(entries.keys()):
			print(f'{key}={entries[key]}', file=f, end='\n')


if __name__ == '__main__':
	main()
