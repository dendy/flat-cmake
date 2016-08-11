
import argparse
import os.path
import xml.dom.minidom as dom

import utils


if __name__ == '__main__':
	ns = 'http://schemas.android.com/apk/res/android'

	parser = argparse.ArgumentParser()
	parser.add_argument('--manifest', required=True)
	parser.add_argument('--platforms-dir', dest='platformsDir', required=True)
	parser.add_argument('--available-platforms-file', dest='availablePlatformsFile', required=True)
	parser.add_argument('--platform')
	parser.add_argument('--target', required=True)
	parser.add_argument('--platform-file', dest='platformFile', required=True)
	parser.add_argument('--package-name-file', dest='packageNameFile', required=True)

	args = parser.parse_args()

	class Platform:
		def __init__(self, name):
			self.name = name
			self.api = Platform.__api(name)

		def __api(name):
			try:
				return int(utils.getProperty(os.path.join(args.platformsDir, name, 'source.properties'),
						'AndroidVersion.ApiLevel'))
			except OSError:
				pass
			except ValueError:
				pass
			return 0

	with open(args.availablePlatformsFile, 'r') as f:
		availablePlatforms = [Platform(name.strip()) for name in f]

	doc = dom.parse(args.manifest)

	packageName = doc.documentElement.getAttribute('package')

	try:
		usesSdkElement = doc.documentElement.getElementsByTagName('uses-sdk')[0]
		def getApiLevel(e):
			if e.hasAttributeNS(ns, 'targetSdkVersion'):
				return e.getAttributeNS(ns, 'targetSdkVersion')
			if e.hasAttributeNS(ns, 'minSdkVersion'):
				return e.getAttributeNS(ns, 'minSdkVersion')
			return 1
		targetApiLevel = int(getApiLevel(usesSdkElement))
	except IndexError:
		targetApiLevel = 1

	def overwrite(file, value):
		try:
			with open(file, 'r') as f:
				previousValue = f.readline().strip()
				if previousValue == value:
					return
		except OSError:
			pass

		os.makedirs(os.path.dirname(file), exist_ok=True)
		with open(file, 'w') as f:
			f.write(value + '\n')

	if args.platform:
		matchingPlatforms = [p for p in availablePlatforms if p.name == args.platform and p.api >= targetApiLevel]

		if not matchingPlatforms:
			raise RuntimeError('No platform found for name:', args.platform, '({})'.format(targetApiLevel),
					'Available platforms:', ['{n} ({a})'.format(n=p.name, a=p.api) for p in availablePlatforms])

		if len(matchingPlatforms) != 1:
			raise RuntimeError('Multiple platforms found for name:', args.platform,
					'Found platforms API levels:', [p.api for p in availablePlatforms if p.name == args.platform])

		platform = matchingPlatforms[0]
	else:
		platform = None
		for p in availablePlatforms:
			if p.api >= targetApiLevel:
				if not platform or p.api > platform.api:
					platform = p

		if not platform:
			raise RuntimeError('No suitable platforms found for API level:', targetApiLevel,
					'Available platforms:', ['{n} ({a})'.format(n=p.name, a=p.api) for p in availablePlatforms])

	overwrite(args.platformFile, platform.name)
	overwrite(args.packageNameFile, packageName)

	os.makedirs(os.path.dirname(args.target), exist_ok=True)
	with open(args.target, 'w') as f:
		pass
