
import sys
import argparse
import subprocess
import os.path
import glob


def localPathToCygwinPath(path):
	if sys.platform != 'win32':
		return path
	if path[1:3] == ':/':
		return '/cygdrive/' + path.replace(':/','/', 1)
	else:
		return path


def toCygwinPath(path):
	cygwinPath = path
	isLocal = False

	protocolPos = path.find('://')
	if protocolPos == -1:
		cygwinPath = localPathToCygwinPath(path)
		if cygwinPath == path:
			isLocal = ':' not in path
		else:
			isLocal = True
	else:
		protocol = path[:protocolPos]
		if protocol == 'file':
			isLocal = True
			cygwinPath = localPathToCygwinPath(path[protocolPos + 3:])

	return (cygwinPath, isLocal)


class Entry:
	pass


class Main:
	def __init__(self):
		argParser = argparse.ArgumentParser()
		argParser.add_argument('--rsync')
		argParser.add_argument('--destination-root', dest='destinationRoot')
		argParser.add_argument('--source')
		argParser.add_argument('--destination')
		argParser.add_argument('--delete')
		argParser.add_argument('--copy-symlinks', dest='copySymlinks')
		argParser.add_argument('--excludes')

		self.args = argParser.parse_args()

		self.rsync = self.args.rsync if self.args.rsync else 'rsync'


	def exec(self):
		fileSep = '!!fs!!'
		excludeSep = '!!es!!'

		source = self.args.source.split(fileSep)
		destination = self.args.destination.split(fileSep)
		delete = self.args.delete.split(fileSep)
		copySymlinks = self.args.copySymlinks.split(fileSep)
		excludes = self.args.excludes.split(fileSep)

		self.entries = []

		for i in range(len(source)):
			entry = Entry()
			entry.source = source[i]
			entry.destination = '' if destination[i] == 'ROOT' else destination[i]
			entry.delete = delete[i] == 'YES'
			entry.copySymlinks = copySymlinks[i] == 'YES'
			entry.excludes = [] if excludes[i] == 'NONE' else excludes[i].split(excludeSep)

			self.entries.append(entry)

		self.entriesForTarget = {}

		for entry in self.entries:
			target = (entry.destination, entry.copySymlinks)
			entries = self.entriesForTarget.get(target)
			if not entries:
				entries = [entry]
				self.entriesForTarget[target] = entries
			else:
				entries.append(entry)

		self.existingDestinationDirs = set()

		self.emptyDir = os.path.join(os.path.abspath(os.curdir), 'empty-rsync-dir').replace(os.path.sep, '/')
		os.makedirs(self.emptyDir, exist_ok=True)

		for (destination, copySymlinks), entries in self.entriesForTarget.items():
			excludes = []
			for entry in entries:
				excludes += entry.excludes
			fullDestination = self.args.destinationRoot + '/' + destination
			self.createDestinationDirs(fullDestination)
			self.sync([e.source for e in entries], fullDestination, entries[0].delete, excludes, copySymlinks)


	def createDestinationDirs(self, destination):
		path, isLocal = toCygwinPath(destination)
		if isLocal:
			pathToMake = os.path.split(destination)[0]
			os.makedirs(pathToMake, exist_ok=True)
			return

		names = destination.split('/')[:-1]
		currentDir = ''
		for name in names:
			currentDir += name + '/'
			if currentDir not in self.existingDestinationDirs:
				self.existingDestinationDirs.add(currentDir)
				self.sync([self.emptyDir + '/'], currentDir, strict=False)


	def sync(self, sources, destination, delete=False, excludes=[], copySymlinks=False, verbose=False, strict=True):
		destinationHead, destinationTail = os.path.split(destination)

		sourcePaths = []

		rsyncExcludeArgs = []

		for source in sources:
			if not source or source == '/':
				raise Exception('Invalid source:', source)
			sourceHead, sourceTail = os.path.split(source)
			if not sourceTail and destinationTail:
				raise Exception('Invalid source-destination pair:', destination, source,
						'If source ends with / then destination must also ends with /')
			expandedSources = glob.glob(source)
			expandedSources = [x.replace('\\', '/') for x in expandedSources]
			sourcePaths += expandedSources if len(expandedSources) != 0 else [source];

		if destinationTail:
			if len(sourcePaths) != 1:
				raise Exception('More than one source has same destination path:', destination, sourcePaths)
			sourcePath = sourcePaths[0]
			if os.path.isdir(sourcePath):
				sourcePaths = [sourcePath + '/']
				destination += '/'

		for exclude in excludes:
			path, isLocal = toCygwinPath(exclude) if sys.platform == 'win32' else (exclude, None)
			rsyncExcludeArgs.append('--exclude=' + path)

		rsyncArgs = []
		rsyncDestination = None
		rsyncSources = []

		if sys.platform == 'win32':
			rsyncDestination, isLocal = toCygwinPath(destination)

			rsyncArgs += ['-rt', '--chmod=ugo=rwx']
			if not isLocal:
				rsyncArgs += ['-p']

			for sourcePath in sourcePaths:
				rsyncSource, isLocal = toCygwinPath(sourcePath)
				rsyncSources.append(rsyncSource)
		else:
			rsyncArgs += ['-a']
			rsyncDestination = destination
			rsyncSources = sourcePaths

		if verbose:
			rsyncArgs += ['-v']

		if delete:
			rsyncArgs += ['--delete']

		if sys.platform == 'linux' and copySymlinks:
			rsyncArgs += ['-L']

		allRsyncArgs = [self.rsync] + rsyncArgs + rsyncSources + rsyncExcludeArgs + [rsyncDestination]

		simulate = False
		if simulate:
			print('args:', allRsyncArgs)
		else:
			rsync = subprocess.run(allRsyncArgs, universal_newlines=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL if not strict else subprocess.STDOUT)

			if strict and rsync.returncode != 0:
				print('\nRsync failed. Arguments:\n\n', ' '.join(allRsyncArgs), '\n\nOutput:\n\n', rsync.stdout, file=sys.stderr)
				raise Exception('Code: {}'.format(rsync.returncode))


Main().exec()
