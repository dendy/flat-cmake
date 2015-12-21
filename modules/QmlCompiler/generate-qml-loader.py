
import argparse
import os.path
import subprocess
import enum

class Looking(enum.Enum):
	nameStart = 1
	nameEnd = 2
	treeStart = 3
	treeEnd = 4

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--output')
	parser.add_argument('--qrc')
	parser.add_argument('--qml-compiler', dest='qmlCompiler')
	parser.add_argument('--rcc')
	parser.add_argument('--no-fix', dest='fix', action='store_false')
	args = parser.parse_args()

	outputDir = os.path.dirname(args.output)
	loaderFileName = os.path.basename(args.output)

	os.makedirs(outputDir, exist_ok=True)

	originalLoaderFilePath = os.path.join(outputDir, loaderFileName + '.original.cpp')
	rccLoaderFilePath = os.path.join(outputDir, loaderFileName + '.rcc.cpp')

	subprocess.run([args.qmlCompiler, args.qrc, originalLoaderFilePath if args.fix else args.output], check=True)

	if args.fix:
		subprocess.run([args.rcc, '-o', rccLoaderFilePath, args.qrc], check=True)

		kNameTag = 'static const unsigned char qt_resource_name[] = {\n'
		kTreeTag = 'static const unsigned char qt_resource_struct[] = {\n'

		looking = Looking.nameStart

		nameLines = []
		treeLines = []

		with open(rccLoaderFilePath, 'r') as f:
			for line in f:
				if looking == Looking.nameStart:
					if line == kNameTag:
						looking = Looking.nameEnd
					continue

				if looking == Looking.nameEnd:
					if line == '};\n':
						looking = Looking.treeStart
					else:
						nameLines.append(line)
					continue

				if looking == Looking.treeStart:
					if line == kTreeTag:
						looking = Looking.treeEnd
					continue

				if looking == Looking.treeEnd:
					if line == '};\n':
						break
					else:
						treeLines.append(line)
					continue

		fixedTreeLines = []
		for line in treeLines:
			line = line.strip()
			if line and not line.startswith('//'):
				bytes = [int(x, 16) for x in line.split(',') if x != '']
				type = bytes[5]
				if type == 0 or type == 1:
					bytes[5] = 0
					bytes = bytes[:10] + [0, 0, 0, 0]
					line = ','.join(['0x{0:02x}'.format(x) for x in bytes]) + ','
			fixedTreeLines.append('  ' + line + '\n')

		with open(originalLoaderFilePath, 'r') as f:
			with open(args.output, 'w') as fw:
				fw.write('namespace __fixed_qt_resource {\n')
				fw.write('static const unsigned char tree[] = {\n' + ''.join(fixedTreeLines) + '\n};\n\n')
				fw.write('static const unsigned char name[] = {\n' + ''.join(nameLines) + '\n};\n}\n\n')

				for line in f:
					if line == 'QT_PREPEND_NAMESPACE(qRegisterResourceData)(/*version*/0x01, qt_resource_tree, qt_resource_names, qt_resource_empty_payout);\n':
						line = 'QT_PREPEND_NAMESPACE(qRegisterResourceData)(/*version*/0x01, __fixed_qt_resource::tree, __fixed_qt_resource::name, qt_resource_empty_payout);\n'
					fw.write(line)
