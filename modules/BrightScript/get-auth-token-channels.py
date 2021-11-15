#!/usr/bin/env python3

import argparse


def main():
	parser = argparse.ArgumentParser()
	parser.add_argument('--user', required=True)
	parser.add_argument('--yo', required=True)
	args = parser.parse_args()


if __name__ == '__main__':
	main()
