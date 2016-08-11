
import argparse


if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--res-dir', dest='resDir', required=True)
	parser.add_argument('--source-files-target', dest='sourceFilesTarget', required=True)
	parser.add_argument('--package-files-target', dest='packageFilesTarget', required=True)

	args = parser.parse_args()


