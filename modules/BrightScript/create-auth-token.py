#!/usr/bin/env python3


import argparse
import os.path
import yaml


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument('--user', required=True)
	parser.add_argument('--user-required', action='store_true')
	parser.add_argument('--file', required=True)
	parser.add_argument('--id', required=True)
	parser.add_argument('--done-file', required=True)
	parser.add_argument('--manifest-file', required=True)
	args = parser.parse_args()

	try:
		with open(args.manifest_file, 'r') as f:
			old_manifest = yaml.load(f, Loader=yaml.FullLoader)
			old_token = old_manifest.get('channel_token')
			has_old_manifest = True
	except:
		old_token = None
		has_old_manifest = False
#	print(f'old_token={old_token};')

	with open(args.file, 'r') as f:
		users = yaml.load(f, Loader=yaml.FullLoader)
#	print(f'users={users};')

	new_token = None

	user = users.get(args.user)
	if user is None:
		if args.user_required:
			raise AttributeError(f'Required user is missing in auth-token config file: {args.user}')
	else:
		for entry in user:
			if args.id in entry['channels']:
				new_token = entry['token']
				break

#	print(f'new_token={new_token};')
#	if new_token is None:
#		raise AttributeError(f'Cannot find auth token for channel id: {args.channel_id}')

	if not has_old_manifest or old_token != new_token:
		with open(args.manifest_file, 'w') as f:
			f.write(yaml.dump({'channel_token': new_token}, Dumper=yaml.Dumper))

	with open(args.done_file, 'w') as f:
		pass


if __name__ == '__main__':
	main()
