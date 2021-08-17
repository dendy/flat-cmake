
import os.path
import yaml


class Device:
	def __init__(self, name=None):
		with open(os.path.expanduser('~/.roku/config/devices.yaml'), 'r') as f:
			config = yaml.load(f, Loader=yaml.FullLoader)

		default = config.get('default')
		devices = config.get('devices')

		if name is None:
			name = default['device']

		device = devices[name]

		self.name = name
		self.device = device
		self.default = default

		self.address = self.param('address')
		self.password = self.param('password')

	def param(self, key):
		value = self.device.get(key)
		if value is None:
			value = self.default.get(key)
		return value


class Secret:
	def __init__(self):
		with open(os.path.expanduser('~/.roku/secret.yaml'), 'r') as f:
			self.secret = yaml.load(f, Loader=yaml.FullLoader)

		self.devid = self.param('devid')
		self.password = self.param('password')

	def param(self, key):
		return self.secret.get(key)
