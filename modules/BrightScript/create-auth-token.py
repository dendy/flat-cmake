#!/usr/bin/env python3


import argparse
import os.path
import yaml


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument('--done-file', required=True)
	parser.add_argument('--manifest-file', required=True)
	parser.add_argument('--auth-tokens-file', required=True)
	parser.add_argument('--channel-id', required=True)
	args = parser.parse_args()

	try:
		with open(args.manifest_file, 'r') as f:
			old_token = yaml.load(f, Loader=yaml.FullLoader)['channel_token']
	except:
		old_token = None
#	print(f'old_token={old_token};')

	with open(args.auth_tokens_file, 'r') as f:
		auth_token_entries = yaml.load(f, Loader=yaml.FullLoader)
#	print(f'tokens={auth_token_entries};')

	new_token = None
	for entry in auth_token_entries:
		if args.channel_id in entry['channels']:
			new_token = entry['token']
			break

#	print(f'new_token={new_token};')
	if new_token is None:
		raise AttributeError(f'Cannot find auth token for channel id: {args.channel_id}')

	if old_token is None or old_token != new_token:
		with open(args.manifest_file, 'w') as f:
			f.write(yaml.dump({'channel_token': new_token}, Dumper=yaml.Dumper))

	with open(args.done_file, 'w') as f:
		pass


if __name__ == '__main__':
	main()


