#!/usr/bin/env python3


import yaml
import os.path
import fnmatch
import glob
import argparse


def run(config, root_dir, project_dir, local=None):
	with open(config, 'r') as f:
		config = yaml.load(f, Loader=yaml.FullLoader)

	name = config['name']

	os.makedirs(project_dir, exist_ok=True)

	with open(f'{project_dir}/{name}.creator', 'w') as f:
		print('[General]', file=f)

	with open(f'{project_dir}/{name}.cflags', 'w') as f:
		print(' '.join(config['cflags']), file=f)

	with open(f'{project_dir}/{name}.cxxflags', 'w') as f:
		print(' '.join(config['cxxflags']), file=f)

	with open(f'{project_dir}/{name}.config', 'w') as f:
		macros = config.get('macros')
		if not macros is None:
			for key, value in macros.items():
				value_type = type(value)
				if value is None:
					print(f'#define {key}', file=f)
				elif value_type == str:
					print(f'#define {key} "{value}"', file=f)
				else:
					print(f'#define {key} {value}', file=f)

	def user_expanded_value(value):
		if value.startswith('~'):
			return os.path.expanduser(value)
		else:
			return value

	if not local is None:
		with open(local, 'r') as f:
			local = yaml.load(f, Loader=yaml.FullLoader)
			local_mappings = local.get('mappings')
			if not local_mappings is None:
				local_mappings = {key: user_expanded_value(value)
						for key, value in local_mappings.items()}
	else:
		local_mappings = None

	def expand_path(path):
		nonlocal local_mappings
		nonlocal root_dir
		expanded_path = path
		if not local_mappings is None:
			for key, value in local_mappings.items():
				expanded_path = expanded_path.replace(f'${key}', value)
		if '$' in expanded_path:
			raise AttributeError(f'Path not fully expanded: {path}')
		if not os.path.isabs(expanded_path):
			expanded_path = f'{root_dir}/{expanded_path}'
		return expanded_path

	with open(f'{project_dir}/{name}.includes', 'w') as f:
		includes = config.get('includes')
		if not includes is None:
			for include in includes:
				expanded_include = expand_path(include)
				print(expanded_include, file=f)

	ignores = config.get('ignore')
	def is_ignored(path):
		nonlocal ignores
		if ignores is None: return False
		for i in ignores:
			if fnmatch.fnmatchcase(path, i): return True
		return False

	exclude_paths = []
	excludes = config.get('exclude')
	if not excludes is None:
		for path in excludes:
			expanded_path = expand_path(path)
			exclude_paths += glob.glob(expanded_path, recursive=True)
#	print(f'exclude_paths={exclude_paths};')

	with open(f'{project_dir}/{name}.files', 'w') as f:
		for path in config['files']:
			expanded_path = expand_path(path)
			#print(f'path={path}; {expanded_path};')
			files = glob.glob(expanded_path, recursive=True)
			#print(f'file={files};')
			for fp in files:
				if os.path.isfile(fp):
					if not is_ignored(fp):
						if not fp in exclude_paths:
							print(fp, file=f)


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument('--config', required=True)
	parser.add_argument('--root-dir', required=True)
	parser.add_argument('--project-dir', required=True)
	parser.add_argument('--local')
	args = parser.parse_args();

	run(args.config, args.root_dir, args.project_dir, args.local)


if __name__ == '__main__':
	main()
