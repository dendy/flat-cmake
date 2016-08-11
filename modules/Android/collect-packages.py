
import argparse
import os.path


if __name__ == '__main__':
	parser = argparse.ArgumentParser()
	parser.add_argument('--dir', required=True)
	parser.add_argument('--output', required=True)

	args = parser.parse_args()

	previous = None
	try:
		with open(args.output, 'r') as f:
			previous = [name.strip() for name in f]
	except OSError:
		pass
	except json.JSONDecodeError:
		pass

	dir = args.dir

	names = [name for name in os.listdir(dir) \
			if os.path.isfile(os.path.join(dir, name, 'source.properties'))]

	def isOutdated():
		if previous == None:
			return True

		if set(names) ^ set(previous):
			return True

		# previous name cache exists and matches current list, compare timestamps
		outputTime = os.stat(args.output).st_mtime_ns
		for name in names:
			if os.stat(os.path.join(dir, name, 'source.properties')).st_mtime_ns > outputTime:
				return True

		return False

	if isOutdated():
		with open(args.output, 'w') as f:
			for name in names:
				f.write(name)
				f.write('\n')
