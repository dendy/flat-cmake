
import argparse
import os.path
import subprocess
import shutil
import glob


if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--res-dir', dest='resDir', required=True)
	parser.add_argument('--output-dir', dest='outputDir', required=True)
	parser.add_argument('--manifest-file', dest='manifestFile', required=True)
	parser.add_argument('--platforms-dir', dest='platformsDir', required=True)
	parser.add_argument('--build-tools-dir', dest='buildToolsDir', required=True)
	parser.add_argument('--package-name-file', dest='packageNameFile', required=True)
	parser.add_argument('--build-tools-file', dest='buildToolsFile', required=True)
	parser.add_argument('--platform-file', dest='platformFile', required=True)
	parser.add_argument('--verbose', action='store_true')
	parser.add_argument('--target-file', dest='targetFile', required=True)

	args = parser.parse_args()

	with open(args.packageNameFile, 'r') as f:
		packageName = f.read().strip()

	with open(args.buildToolsFile, 'r') as f:
		buildToolsName = f.read().strip()

	with open(args.platformFile, 'r') as f:
		platformName = f.read().strip()

	packagePath = packageName.replace('.', '/')

	# make clean output directory
	if os.path.isdir(args.outputDir):
		shutil.rmtree(args.outputDir)
	os.makedirs(args.outputDir)

	aapt_extra_args = []

	if args.verbose:
		aapt_extra_args.append('-v')

	aapt = subprocess.run(
			[os.path.join(args.buildToolsDir, buildToolsName, 'aapt'), 'package'] +
			aapt_extra_args +
			['-f'] +
			['-m', '-J', args.outputDir] +
			['-M', args.manifestFile] +
			['-S', args.resDir] +
			['-I', os.path.join(args.platformsDir, platformName, 'android.jar')],
			universal_newlines=True, stderr=subprocess.PIPE, check=True)

	javaFiles = glob.glob(args.outputDir + os.path.sep + '**' + os.path.sep + '*.java', recursive=True)

	# generate target file
	os.makedirs(os.path.dirname(args.targetFile), exist_ok=True)
	with open(args.targetFile, 'w') as f:
		for javaFile in javaFiles:
			f.write(javaFile)
			f.write('\n')
