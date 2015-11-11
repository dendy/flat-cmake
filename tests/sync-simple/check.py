
import argparse
import filecmp
import sys


class Main:
	def __init__(self):
		argParser = argparse.ArgumentParser()
		argParser.add_argument('--same', nargs=2)

		self.args = argParser.parse_args()


	def exec(self):
		if self.args.same:
			return self.same(self.args.same[0], self.args.same[1])

		return 1


	def same(self, file1, file2):
		return 0 if filecmp.cmp(file1, file2) else 1


sys.exit(Main().exec())
