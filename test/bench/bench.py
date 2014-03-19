#!/usr/bin/env python
# coding: UTF-8
#
# Run bee script for all bee versions. Run script with:
#
#   yes | ./bench.py

import os
import time

VERSIONS = ['0.1.0', '0.1.1', '0.2.0', '0.3.0', '0.3.1', '0.4.0', '0.5.0',
            '0.5.1', '0.5.2', '0.5.3', '0.6.0']
NB_CALLS = 3

# Excute a given command.
def execute(command):
    result = os.system(command)
    if result != 0:
        raise Exception("Error running command: '%s'" % command)

# Bench a given version.
def bench_version(version):
    execute("sudo gem uninstall bee")
    execute("sudo gem install bee -v %s" % version)
    execute("bee")
    somme = 0
    for i in range(NB_CALLS):
        start = time.time()
        execute("bee")
        somme += time.time() - start
    return somme / NB_CALLS

# Bench
def bench():
    times = {}
    for version in VERSIONS:
        times[version] = bench_version(version)
    result = ''
    for version in sorted(VERSIONS):
        result += "%s, %s\n" % (version, times[version])
    print result

# parse command line
if __name__ == '__main__':
    bench()
