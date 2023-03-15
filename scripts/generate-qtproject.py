#!/usr/bin/env python3


import yaml
import os.path
import fnmatch
import glob
import argparse
import sys


def run(config_path, root_dir, project_dir, local_path=None):
	config_path = os.path.realpath(config_path)
	root_dir = os.path.realpath(root_dir)

	platform_name_for_sys_platform = dict(
		linux  = 'linux',
		win32  = 'win',
		darwin = 'mac',
	)
	platform_name = platform_name_for_sys_platform[sys.platform]

	def check_valid_platform_name(name):
		for value in platform_name_for_sys_platform.values():
			if name == value: return
		raise AttributeError(f'Invalid platform name: {name}')

	def get_platform_paths(d):
		# check that all keys in the d are valid platform names
		for key in d.keys():
			check_valid_platform_name(key)
		paths = d.get(platform_name)
		if paths is None: paths = []
		return paths

	with open(config_path, 'r') as f:
		config = yaml.load(f, Loader=yaml.FullLoader)

	name = config['name']

	if not local_path is None:
		with open(local_path, 'r') as f:
			local = yaml.load(f, Loader=yaml.FullLoader)
	else:
		local = None

	os.makedirs(project_dir, exist_ok=True)

	def get_object(key, required):
		nonlocal config
		nonlocal local
		if required:
			c = config[key]
		else:
			c = config.get(key)
		if local is None:
			l = None
		else:
			l = local.get(key)
		return c, l

	def get_array(key, required):
		c, l = get_object(key, required)
		if c is None and l is None: return
		if c is None: c = []
		if not l is None:
			c += l
		return c

	def get_dict(key, required):
		c, l = get_object(key, required)
		if c is None and l is None: return
		if c is None: c = dict()
		if not l is None:
			c.update(l)
		return c

	with open(f'{project_dir}/{name}.creator', 'w') as f:
		print('[General]', file=f)

	with open(f'{project_dir}/{name}.cflags', 'w') as f:
		print(' '.join(get_array('cflags', True)), file=f)

	with open(f'{project_dir}/{name}.cxxflags', 'w') as f:
		print(' '.join(get_array('cxxflags', True)), file=f)

	with open(f'{project_dir}/{name}.config', 'w') as f:
		macros = get_dict('macros', False)
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
		local_mappings = local.get('mappings')
		if not local_mappings is None:
			local_mappings = {key: user_expanded_value(value)
					for key, value in local_mappings.items()}
	else:
		local_mappings = None

	if local_mappings is None:
		local_mappings = dict()
	#print(f'config_path={config_path};')
	local_mappings['config_dir'] = os.path.dirname(config_path)

	def expand_path(path):
		nonlocal local_mappings
		nonlocal root_dir
		expanded_path = os.path.expanduser(path)
		if not local_mappings is None:
			for key, value in local_mappings.items():
				expanded_path = expanded_path.replace(f'${key}', value)
		if '$' in expanded_path:
			raise AttributeError(f'Path not fully expanded: {path}')
		if not os.path.isabs(expanded_path):
			expanded_path = f'{root_dir}/{expanded_path}'
		return os.path.realpath(expanded_path)

	def process_include(include):
		if type(include) != str:
			raise AttributeError(f'Invalid entry: {include}')
		expanded_include = expand_path(include)
		print(expanded_include, file=f)
		if not os.path.isdir(expanded_include):
			print(f'WARNING: Include does not exist: {expanded_include}')

	with open(f'{project_dir}/{name}.includes', 'w') as f:
		includes = get_array('includes', False)
		if not includes is None:
			for include in includes:
#				print(include)
				if type(include) == dict:
					for platform_include in get_platform_paths(include):
						process_include(platform_include)
				else:
					process_include(include)

	ignores = get_array('ignore', False)
	def is_ignored(path):
		nonlocal ignores
		if ignores is None: return False
		for i in ignores:
			if fnmatch.fnmatchcase(path, i): return True
		return False

	exclude_prefixes = []
	exclude_paths = []
	excludes = get_array('exclude', False)
	if not excludes is None:
		for path in excludes:
			expanded_path = expand_path(path)
			if '*' in expanded_path:
				exclude_paths += glob.glob(expanded_path, recursive=True)
			else:
				exclude_prefixes.append(expanded_path)
	#print(f'exclude_paths={exclude_paths};')
	#print(f'exclude_prefixes={exclude_prefixes};')

	def is_excluded_prefix(path):
		nonlocal exclude_prefixes
		for p in exclude_prefixes:
			if path.startswith(p):
				return True
		return False

	with open(f'{project_dir}/{name}.files', 'w') as f:
		for path in get_array('files', True):
			print(file=f)
			print(f'# {path}', file=f)
			expanded_path = expand_path(path)

			if is_excluded_prefix(expanded_path):
				#print(f'excluded: {expanded_path}')
				continue

			#print(f'path={path}; {expanded_path}; root_dir={root_dir};')
			files = glob.glob(expanded_path, recursive=True)
			#print(f'file={files};')
			total_count = 0
			added_count = 0
			for fp in files:
				if not os.path.isfile(fp):
					continue
				total_count += 1
				if is_excluded_prefix(fp):
					continue
				if is_ignored(fp):
					continue
				if fp in exclude_paths:
					continue
				print(fp, file=f)
				added_count += 1

			if total_count == 0:
				print(f'WARNING: Path does not have files: {expanded_path}')


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
