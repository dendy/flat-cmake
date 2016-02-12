
import argparse
import io

kVersionToken = '#if QT_VERSION !='
kHeaderToken = '#include <private/qv4value_inl_p.h>'

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--version')
	parser.add_argument('--input')
	parser.add_argument('--output')
	args = parser.parse_args()

	version = '0x'
	for number in args.version.split('.'):
		version += '{0:02x}'.format(int(number))

	is56 = args.version.startswith('5.6')

	buffer = io.StringIO()

	buffer.write('#include <private/qv4string_p.h>' + '\n')

	with open(args.input, 'r') as f:
		for line in f:
			if line.startswith(kVersionToken):
				line = kVersionToken + ' ' + version + '\n'
			elif is56:
				if line.startswith(kHeaderToken):
					line = '#include <private/qv4value_p.h>' + '\n'
				else:
					line = line.replace('engine->currentContext()', 'engine->current')
					line = line.replace('static_cast<QV4::CallContext::Data*>(engine->current->outer)', 'engine->current->outer.cast<QV4::CallContext::Data>()')
			buffer.write(line)

	with open(args.output, 'w') as f:
		f.write(buffer.getvalue())
