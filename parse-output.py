#!/usr/bin/python

import os
import subprocess
import fnmatch
import csv
from bz2 import BZ2File as bz
import matplotlib as mpl

mpl.use('Agg')
import matplotlib.pyplot

def main():

  sites = set()

  for i in os.listdir('output'):
    sites.add(i.split('-')[0])

  print 'Found %d sites.' % len(sites)

  for site in sites:
    print site
    conns = bz('output/' + site + '-conns.csv.bz2').read()
    connsM = bz('output/' + site + '-m-conns.csv.bz2').read()
    print conns
    conns = map(lambda x: int(x), stripBlanks(conns))
    connsM = map(lambda x: int(x), stripBlanks(connsM))

def stripBlanks(line):
  return os.linesep.join([s for s in line.splitlines() if s.strip()])

main()

