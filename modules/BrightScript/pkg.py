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
import time

import brs


class LineParser(html.parser.HTMLParser):
	def __init__(self):
		html.parser.HTMLParser.__init__(self)
		self.tree = []
		self.file = None
		self.message = None

	def handle_starttag(self, tag, attrs):
#		print(f'starttag {tag} {attrs}')
		self.tree.append((tag, attrs))

	def handle_endtag(self, etag):
#		print(f'starttag {etag}')
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
#		print(f'path={current_path}')

		if current_path == 'div/font':
			self.message = data
		elif current_path == 'div/font/a':
#			print(f'pkg={data};')
			self.file = data


class PkgParser(html.parser.HTMLParser):
	def __init__(self):
		html.parser.HTMLParser.__init__(self)
		self.tree = []
		self.found_answers = []
		self.success = False
		self.file = None

	def handle_starttag(self, tag, attrs):
#		print(f'starttag {tag} {attrs}')
		self.tree.append((tag, attrs))

	def handle_endtag(self, etag):
#		print(f'starttag {etag}')
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
#		print(f'path={current_path}')

		if current_path == 'html/body/div/font':
			answer = data.strip()
			self.found_answers.append(answer)
			if answer == 'Success.':
				self.success = True
		elif current_path == 'html/body/script':
#			print(f'script: {data}')
			for line in data.splitlines():
				if 'pkgDiv.innerHTML =' in line:
#					print(f'line: {line};')
					try:
						begin_pos = line.find('\'')
						if begin_pos == -1: raise RuntimeError()
						end_pos = line.find('\'', begin_pos + 1)
						if end_pos == -1: raise RuntimeError()
						line_body = line[begin_pos + 1:end_pos]
#						print(f'line_body={line_body};')
						line_parser = LineParser()
						line_parser.feed(line_body)
						if line_parser.file is None: raise RuntimeError(line_parser.message)
						self.file = line_parser.file
					except RuntimeError as e:
						raise RuntimeError(f'Invalid pkg line: {line}')
					break;


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument('--output', required=True)
	parser.add_argument('--device', required=False)
	args = parser.parse_args()

	device = brs.Device(args.device)
	secret = brs.Secret()
#	print(f'{secret.devid} {secret.password}')

	pkg_file = None

	def make_pkg():
		nonlocal args
		nonlocal device
		nonlocal secret
		nonlocal pkg_file
		print(f'    Creating pkg')

		pkg_time = int(time.time() * 1000)
#		print(f'pkg_time={pkg_time}')

		curl_cli = ['curl',
			'--user', f'rokudev:{device.password}',
			'--digest',
			'--silent',
			'--show-error',
			'-F', 'mysubmit=Package',
			'-F', 'app_name=yo',
			'-F', f'passwd={secret.password}',
			'-F', f'pkg_time={pkg_time}',
			f'http://{device.address}/plugin_package'
		]

		html_body = subprocess.run(curl_cli, check=True, stdout=subprocess.PIPE,
				universal_newlines=True).stdout
#		print(html_body)

		pkg_parser = PkgParser()
		pkg_parser.feed(html_body)

		if not pkg_parser.success:
			for answer in pkg_parser.found_answers:
				print(f'{answer}', file=sys.stderr)
			raise RuntimeError('Pkg creation failed')

		print(f'        Pkg created: {pkg_parser.file}')
		pkg_file = pkg_parser.file

	def download_pkg():
		nonlocal args
		nonlocal device
		nonlocal secret
		nonlocal pkg_file
		print(f'    Downloading pkg')

		curl_cli = ['curl',
			'--user', f'rokudev:{device.password}',
			'--digest',
			'--silent',
			'--show-error',
			'--output', args.output,
			f'http://{device.address}/pkgs/{pkg_file}'
		]

		subprocess.run(curl_cli, check=True, stdout=subprocess.PIPE,
				universal_newlines=True).stdout

		print(f'        Success')

	make_pkg()
	download_pkg()


if __name__ == '__main__':
	main()
