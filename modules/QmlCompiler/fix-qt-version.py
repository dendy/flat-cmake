
import argparse
import io

kVersionToken = '#if QT_VERSION !='

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--version')
	parser.add_argument('--input')
	parser.add_argument('--output')
	args = parser.parse_args()

	print(args.input)
	print(args.output)

	version = '0x'
	for number in args.version.split('.'):
		version += '{0:02x}'.format(int(number))

	fixed = False

	buffer = io.StringIO()

	with open(args.input, 'r') as f:
		for line in f:
			if line.startswith(kVersionToken):
				line = kVersionToken + ' ' + version + '\n'
			buffer.write(line)

	with open(args.output, 'w') as f:
		f.write(buffer.getvalue())
