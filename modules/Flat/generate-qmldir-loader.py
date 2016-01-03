
import argparse
import posixpath as posixpath

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--qmldir')
	parser.add_argument('--prefix')
	parser.add_argument('--loader')
	parser.add_argument('--exclude', nargs='*', default=[])
	parser.add_argument('--include', nargs='*')

	args = parser.parse_args()

	if args.include:
		for exclude in args.exclude:
			if exclude in args.include:
				raise Exception('Matching include and exclude:', exclude)

	class Entry:
		pass

	entries = []

	def parseVersion(s):
		v = s.split('.')
		if len(v) != 2:
			raise Exception('Invalid version:', s)
		return v

	def checkVersion(s):
		try:
			return parseVersion(s)
		except:
			pass

	def parseClass(args):
		if len(args) < 3:
			return

		if args[0] == 'singleton':
			if len(args) != 4:
				raise Exception('Invalid singleton:', line)
			entry = Entry()
			entry.name = args[1]
			entry.version = parseVersion(args[2])
			entry.file = args[3]
			entry.singleton = True
			entries.append(entry)
			return

		if len(args) == 3:
			version = checkVersion(args[1])
			if version:
				entry = Entry()
				entry.name = args[0]
				entry.version = version
				entry.file = args[2]
				entry.singleton = False
				entries.append(entry)
			return

	with open(args.qmldir, 'r') as f:
		for line in f:
			s = line.split()
			if s:
				key = s[0]
				if key == 'module':
					if len(s) != 2:
						raise Exception('Invalid module:', line)
					module = s[1]
				parseClass(s)

	with open(args.loader, 'w') as f:
		modulePath = module.split('.')

		f.write('#include <QQmlComponent>\n')
		f.write('\n')

		f.write('void flat_qmldir_loader_{func}()\n'.format(func='_'.join(modulePath)))
		f.write('{\n')

		for entry in entries:
			if entry.name in args.exclude:
				continue

			if args.include and not entry.name in args.include:
				continue

			f.write('\t{func}(QUrl(QLatin1String("qrc://{file}")), "{uri}", {version_major}, {version_minor}, "{name}");\n'.format(
					func='qmlRegisterType' if not entry.singleton else 'qmlRegisterSingletonType',
					file=posixpath.join(args.prefix, posixpath.join(*modulePath), entry.file),
					uri=module,
					version_major=entry.version[0],
					version_minor=entry.version[1],
					name=entry.name)
			)

		f.write('}\n')
