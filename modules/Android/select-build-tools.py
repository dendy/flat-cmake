
import argparse
import os.path

import utils


if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--dir', required=True)
	parser.add_argument('--available-build-tools-file', dest='availableBuildToolsFile', required=True)
	parser.add_argument('--output', required=True)
	parser.add_argument('--version')

	args = parser.parse_args()

	class BuildTools:
		def __init__(self, name):
			self.name = name
			self.version = BuildTools.__version(name)

		def __version(name):
			try:
				return utils.getProperty(os.path.join(args.dir, name, 'source.properties'),
						'Pkg.Revision')
			except OSError:
				pass
			except ValueError:
				pass
			return ''

	with open(args.availableBuildToolsFile, 'r') as f:
		availableBuildTools = [BuildTools(name.strip()) for name in f]

	def availableBuildToolsDescription():
		return ', '.join([b.name + '(' + b.version + ')' for b in availableBuildTools])

	buildTools = None
	for b in availableBuildTools:
		if not args.version or b.version.startswith(args.version):
			if not buildTools or b.version > buildTools.version:
				buildTools = b

	if not buildTools:
		raise RuntimeError('No matching build tools found' +
				', available build tools: ' + availableBuildToolsDescription() +
				', requested version: ' + args.version)

	with open(args.output, 'w') as f:
		f.write(buildTools.name)
		f.write('\n')
