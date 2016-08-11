
def getProperty(path, key):
	with open(path, 'r') as f:
		for line in f:
			line = line.strip()
			if line.startswith('#'):
				continue
			k, v = line.split('=', maxsplit=1)
			if k == key:
				return v
		raise ValueError('Key not found:', key)
