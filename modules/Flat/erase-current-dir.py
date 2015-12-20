#!/usr/bin/python3

import shutil

if __name__ == '__main__':
	def error(function, path, excinfo):
		if path != '.':
			raise OSError('Cannot remove:', path)
	
	shutil.rmtree('.', onerror=error)
