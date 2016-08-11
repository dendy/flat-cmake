
import argparse
import os.path

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--android-sdk-dir', dest='androidSdkDir', required=True)
	parser.add_argument('--extras-file', dest='extrasFile', required=True);
	parser.add_argument('--compile-dependency', dest='deps', nargs='*', default=[])
	parser.add_argument('--depends', nargs='*', default=[])
	parser.add_argument('--output', required=True)

	args = parser.parse_args()

	def needUpdate():
		try:
			ts = os.stat(args.output).st_mtime_ns
			try:
				for dep in args.depends:
					if os.stat(dep).st_mtime_ns > ts:
						return True
			except FileNotFoundError as e:
				raise RuntimeError('Dependency does not exist:', e.filename)
		except FileNotFoundError:
			return True

		return False

	if needUpdate():
		with open(args.extrasFile, 'r') as f:
			extras = [l.strip() for l in f]

		for dep in args.deps:
			package, name, version = dep.split(':', 2)
			subpath = os.path.join(package.replace('.', os.path.sep), name, version)
			pomFileName = name + '-' + version + '.pom'

			depDir = None

			for extra in extras:
				dir = os.path.join(args.androidSdkDir, extra, subpath)
				if os.path.isfile(os.path.join(dir, pomFileName)):
					depDir = dir
					break

			if not depDir:
				raise RuntimeError('Compile dependency not found:', dep)

			print(depDir)
