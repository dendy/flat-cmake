
import argparse
import os.path
import sys


class Main:
	def findNs(e, ns):
		a = 'xmlns:' + ns
		while e:
			if e.hasAttribute(a):
				return e.getAttribute(a)
			e = e.parentNode
		raise RuntimeError('NS not found:', ns)

	def __init__(self):
		self.packageNs = 'http://schemas.android.com/repository/android/common/01'
		self.xsiNs = 'http://www.w3.org/2001/XMLSchema-instance'
		self.packageName = 'repository'

		self.packageInfoForType = {
			'platforms': {
				'dirs': 'platforms',
				'ns': 'http://schemas.android.com/sdk/android/repo/repository2/01',
				'type': 'platformDetailsType'
			},
			'build-tools': {
				'dirs': 'build-tools',
				'ns': 'http://schemas.android.com/repository/android/generic/01',
				'type': 'genericDetailsType'
			},
			'extras': {
				'dirs': 'extras',
				'ns': 'http://schemas.android.com/sdk/android/repo/addon2/01',
				'type': 'extraDetailsType'
			}
		}

		parser = argparse.ArgumentParser()
		parser.add_argument('--android-sdk-dir', dest='androidSdkDir', required=True)
		parser.add_argument('--output-dir', dest='outputDir', required=True)
		parser.add_argument('--depends', nargs='*', default=[])

		self.args = parser.parse_args()

		self.packageDirsForType = {}
		for packageType in self.packageInfoForType:
			self.packageDirsForType[packageType] = self.collectPackageDirs(self.packageInfoForType[packageType])

		os.makedirs(self.args.outputDir, exist_ok=True)

		for type, dirs in self.packageDirsForType.items():
			outputFilePath = os.path.join(self.args.outputDir, type)

			needUpdate = False

			if not os.path.isfile(outputFilePath):
				needUpdate = True
			else:
				outputTimeStamp = os.stat(outputFilePath).st_mtime_ns

			if not needUpdate:
				for depend in self.args.depends:
					if os.stat(depend).st_mtime_ns > outputTimeStamp:
						needUpdate = True
						break

			if not needUpdate:
				for dir in dirs:
					if os.stat(os.path.join(self.args.androidSdkDir, dir, 'source.properties')).st_mtime_ns > outputTimeStamp:
						needUpdate = True
						break

			if needUpdate:
				with open(outputFilePath, 'w') as f:
					for dir in dirs:
						f.write(dir)
						f.write('\n')


	def collectPackageDirs(self, info):
		dirs = info['dirs']
		if not isinstance(dirs, list):
			dirs = [dirs]

		dirsToScan = dirs
		packageDirs = []

		while dirsToScan:
			dir = dirsToScan.pop()
			dirPath = os.path.join(self.args.androidSdkDir, dir)
			if os.path.isfile(os.path.join(dirPath, 'source.properties')):
				packageDirs.append(dir)
			else:
				for name in os.listdir(dirPath):
					if os.path.isdir(os.path.join(dirPath, name)):
						dirsToScan.append(os.path.join(dir, name))

		return packageDirs


#	def collectPackagesForInfo(self, info):
#		foundDirs = []

#		for packageDir in packageDirs:
#			try:
#				doc = dom.parse(os.path.join(packageDir, 'package.xml'))

#				if doc.documentElement.namespaceURI != self.packageNs or doc.documentElement.localName != self.packageName:
#					raise RuntimeError('Invalid package.xml')

#				localPackageElement = doc.documentElement.getElementsByTagName('localPackage')[0]

#				typeDetailsElement = localPackageElement.getElementsByTagName('type-details')[0]
#				typePrefix, typeName = typeDetailsElement.getAttributeNS(self.xsiNs, 'type').split(':', 1)
#				typeNs = Main.findNs(typeDetailsElement, typePrefix)

#				if typeNs != info['ns'] or typeName != info['type']:
#					raise RuntimeError('Invalid package type')

#				foundDirs.append(packageDir)
#			except Exception as e:
#				print(e, file=sys.stderr)

#		return foundDirs


if __name__ == '__main__':
	Main()
