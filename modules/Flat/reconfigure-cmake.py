
import argparse
import os.path
import subprocess

if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('dir')
	parser.add_argument('file')
	parser.add_argument('output')
	parser.add_argument('--cmake')
	parser.add_argument('--deps', nargs='*')
	args = parser.parse_args()

	if args.deps:
		hasNewer = False
		buildFileTime = os.path.getmtime(os.path.join(args.dir, args.file))
		for dep in args.deps:
			if os.path.getmtime(dep) > buildFileTime:
				hasNewer = True
				break
		if hasNewer:
			subprocess.run([args.cmake, '.'], cwd=args.dir, check=True)

	if os.path.exists(args.output):
		os.utime(args.output, None)
	else:
		open(args.output, 'a').close()
