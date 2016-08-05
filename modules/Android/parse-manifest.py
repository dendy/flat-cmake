
import argparse
import os.path
import xml.dom.minidom as dom


if __name__ == '__main__':
	ns = 'http://schemas.android.com/apk/res/android'

	parser = argparse.ArgumentParser()
	parser.add_argument('--manifest', required=True)
	parser.add_argument('--target', required=True)
	parser.add_argument('--target-api-level-file', dest='targetApiLevelFile', required=True)
	parser.add_argument('--package-name-file', dest='packageNameFile', required=True)

	args = parser.parse_args()

	doc = dom.parse(args.manifest)

	packageName = doc.documentElement.getAttribute('package')

	try:
		usesSdkElement = doc.documentElement.getElementsByTagName('uses-sdk')[0]
		def getApiLevel(e):
			if e.hasAttributeNS(ns, 'targetSdkVersion'):
				return e.getAttributeNS(ns, 'targetSdkVersion')
			if e.hasAttributeNS(ns, 'minSdkVersion'):
				return e.getAttributeNS(ns, 'minSdkVersion')
			return '1'
		targetApiLevel =  getApiLevel(usesSdkElement)
	except IndexError:
		targetApiLevel = '1'

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

	overwrite(args.targetApiLevelFile, targetApiLevel)
	overwrite(args.packageNameFile, packageName)

	os.makedirs(os.path.dirname(args.target), exist_ok=True)
	with open(args.target, 'w') as f:
		pass
