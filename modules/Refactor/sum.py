#!/usr/bin/env python

import argparse
import hashlib
import binascii

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--input', required=True)
	parser.add_argument('--output', required=True)
	args = parser.parse_args()

	with open(args.output, 'w') as output:
		sum = hashlib.sha1(open(args.input, 'rb').read()).digest()
		output.write(binascii.hexlify(sum).decode())
		output.write('\n')
