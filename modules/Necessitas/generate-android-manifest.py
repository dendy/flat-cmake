#!/usr/bin/env python
# -*- coding: utf-8 -*-

import argparse
import xml.dom.minidom as dom
import os.path


class Main:
	class Jar:
		def __init__(self, path):
			self.path = path
			self.bundling = False
			self.initClass = None


	class Lib:
		def __init__(self, path):
			self.path = path
			self.extends = None


	class QtModule:
		def __init__(self, name):
			self.name = name
			self.jars = []
			self.libs = []
			self.bundled = []
			self.permissions = []
			self.features = []


	def __init__(self):
		self.ns = 'http://schemas.android.com/apk/res/android'

		parser = argparse.ArgumentParser()
		parser.add_argument('--manifest', required=True)
		parser.add_argument('--output', required=True)
		parser.add_argument('--main')
		parser.add_argument('--qt-libs-dir', dest='qtLibsDir')
		parser.add_argument('--qt-module', dest='qtModules', nargs='*', default=[])

		self.args = parser.parse_args()

		self.parseQtModules()

		self.doc = dom.parse(self.args.manifest)

		for i in range(self.doc.documentElement.attributes.length):
			a = self.doc.documentElement.attributes.item(i)
			if a.prefix == 'xmlns' and a.value == self.ns:
				self.nsprefix = a.localName

		self.app = self.doc.documentElement.getElementsByTagName('application')[0]

		for activity in self.app.getElementsByTagName('activity'):
			metaDatas = activity.getElementsByTagName('meta-data')
			metaDataForName = dict(zip([md.getAttributeNS(self.ns, 'name') for md in metaDatas], metaDatas))
			if ( self.args.main ):
				self.insertMetaData(activity, metaDataForName, 'android.app.lib_name', value=self.args.main)

		with open(self.args.output, 'w', newline='\n') as f:
			Main.cleanDoc(self.doc.documentElement)
			self.doc.writexml(f, addindent='\t', newl='\n')


	def parseQtModules(self):
		self.qtModules = {}
		for module in self.args.qtModules:
			doc = dom.parse(os.path.join(self.args.qtLibsDir, 'Qt5' + module + '-android-dependencies.xml'))
			deps = doc.documentElement \
					.getElementsByTagName('dependencies')[0] \
					.getElementsByTagName('lib')[0] \
					.getElementsByTagName('depends')[0]

			for j in deps.getElementsByTagName('jar'):
				jar = Main.Jar(j.getAttribute('file'))
				jar.bundling = j.getAttribute('bundling') == '1'
				if j.hasAttribute('initClass'):
					jar.initClass = j.getAttribute('initClass')

			for l in deps.getElementsByTagName('lib'):
				lib = Main.Lib(j.getAttribute('file'))
				if j.hasAttribute('extends'):
					lib.extends = j.getAttribute('extends')


	def insertMetaData(self, activity, metaDataForName, name, value=None, resource=None):
		if not value and not resource:
			raise Exception('value or resource is mandatory')

		metaData = metaDataForName.get(name)
		if not metaData:
			metaData = self.doc.createElement('meta-data')
			metaData.setAttributeNS(self.ns, self.nsprefix + ':name', name)
			metaDataForName[name] = metaData
			activity.appendChild(metaData)

		metaData.setAttributeNS(self.ns, self.nsprefix + ':value' if value else self.nsprefix + ':resource', value if value else resource)


	def cleanDoc(e):
		nodesToRemove = []
		for n in e.childNodes:
			if n.nodeType == dom.Node.TEXT_NODE or n.nodeType == dom.Node.COMMENT_NODE:
				nodesToRemove.append(n)
			elif n.nodeType == dom.Node.ELEMENT_NODE:
				Main.cleanDoc(n)
		for n in nodesToRemove:
			e.removeChild(n)

if __name__ == '__main__':
	Main()
