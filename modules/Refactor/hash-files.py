#!/usr/bin/env python3

import argparse
import hashlib
import binascii
import os.path
import io

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--files', required=True)
	parser.add_argument('--hashes', required=True)
	args = parser.parse_args()

	try:
		hashData = open(args.hashes, 'r').read()
		hashTime = os.path.getmtime(args.hashes)
		hashForFile = {}
		for line in hashData.splitlines():
			hash, file = line.split(':', maxsplit=1)
			hashForFile[file] = hash
		hasHashes = True
	except (FileNotFoundError, ValueError):
		hasHashes = False

	newHashIo = io.StringIO()

	for file in open(args.files, 'r').read().splitlines():
		if hasHashes and os.path.getmtime(file) <= hashTime:
			hash = hashForFile.get(file)
		else:
			hash = None

		if hash == None:
			hash = binascii.hexlify(hashlib.sha1(open(file, 'rb').read()).digest()).decode()

		newHashIo.write(hash)
		newHashIo.write(':')
		newHashIo.write(file)
		newHashIo.write('\n')

	newHashData = newHashIo.getvalue()

	if not hasHashes or newHashData != hashData:
		open(args.hashes, 'w').write(newHashData)
