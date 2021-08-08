#!/usr/bin/env python3


import argparse
import urllib.parse
import urllib.request
import yaml
import os.path
import xml.etree.ElementTree
import sys
import subprocess
import html.parser


class InstallParser(html.parser.HTMLParser):
	def __init__(self):
		html.parser.HTMLParser.__init__(self)
		self.tree = []
		self.found_answers = []
		self.success = False
		self.same = False

	def handle_starttag(self, tag, attrs):
		self.tree.append((tag, attrs))

	def handle_endtag(self, etag):
		while len(self.tree):
			tag, attrs = self.tree.pop()
			if tag == etag:
				break

	def handle_data(self, data):
		if not self.tree: return

		tag, attrs = self.tree[len(self.tree) - 1]

		def get_path():
			nonlocal self
			path = ''
			for tag, attrs in self.tree:
				if path: path += '/'
				path += tag
			return path

		current_path = get_path()

		if current_path == 'html/body/div/font':
			answer = data.strip()
			self.found_answers.append(answer)
			if answer == 'Install Success.':
				self.success = True
			elif answer == 'Application Received: Identical to previous version -- not replacing.':
				self.success = True
				self.same = True


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument('--package', required=True)
	parser.add_argument('--device', required=False)
	args = parser.parse_args()

	with open(os.path.expanduser('~/.roku/devices-config.yaml'), 'r') as f:
		devices_config = yaml.load(f, Loader=yaml.FullLoader)

	default = devices_config.get('default')
	devices = devices_config.get('devices')

	if args.device:
		device_name = args.device
	else:
		device_name = default['device']

	device = devices[device_name]

	def get_device_param(key):
		nonlocal default
		nonlocal device
		value = device.get(key)
		if value is None:
			value = default.get(key)
		return value

	address = get_device_param('address')
	password = get_device_param('password')
	print(address, password)

	# check ECP, to verify we are talking to a Roku
	def check_device():
		nonlocal address
		print(f'    Checking device at address: {address}')
		response = urllib.request.urlopen(f'http://{address}:8060/query/device-info')
		if response.status != 200:
			raise RuntimeError(f'Error connecting to device: {response.status}')
		body = response.read().decode()
		tree = xml.etree.ElementTree.fromstring(body)
		software_version = tree.find('software-version')
		model_name = tree.find('model-name')
		print(f'        Model: {model_name.text}')
		print(f'        FW version: {software_version.text}')

	# check dev web server
	def check_web_server():
		nonlocal address
		try:
			print(f'    Checking web server at address: {address}')
			# it should return 401 Unauthorized since we aren't passing the password
			response = urllib.request.urlopen(f'http://{address}')
		except urllib.error.HTTPError as e:
			if e.code != 401:
				raise RuntimeError(f'Error connecting to web server: {e}')
			print(f'        Web server is ready')

	def install_package():
		nonlocal args
		nonlocal address
		nonlocal password
		print(f'    Installing package')

		curl_cli = ['curl',
			'--user', f'rokudev:{password}',
			'--digest',
			'--silent',
			'--show-error',
			'-F', 'mysubmit=Install',
			'-F', f'archive=@{args.package}',
			f'http://{address}/plugin_install'
		]

		html_body = subprocess.run(curl_cli, check=True, stdout=subprocess.PIPE,
				universal_newlines=True).stdout
		install_parser = InstallParser()
		install_parser.feed(html_body)

		for answer in install_parser.found_answers:
			print(f'        {answer}')

		if not install_parser.success:
			raise RuntimeError('Sideload failed')

	check_device()
	check_web_server()
	install_package()


if __name__ == '__main__':
	main()
