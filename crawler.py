#!/usr/bin/python
import subprocess
from subprocess import Popen
import os
import signal
from time import time,sleep

from selenium import webdriver

SITES_LIST = 'data/top-10-sites.txt'
MEASURING_SCRIPT = './nettop.stp'
MAX_SITES = 10
SECONDS_PER_SITE = 60

def main():
  if os.getuid() != 0:
    raise Exception('Not running as root')

  sites = open(SITES_LIST, 'r').read().split('\n')

  os.system('mkdir -p output')

  for i, site in enumerate(sites[:MAX_SITES]):
    os.system('rm -f output/%s*' % site)
    site_full = 'http://' + site
    print "[%d of %d] Loading site: %s" % (i+1, MAX_SITES, site_full)
    browser = webdriver.Firefox() # Get local session of firefox

    tstart = time()
    pStap = Popen('%s > output/%s.stap.csv' % (MEASURING_SCRIPT, site), \
        stderr=subprocess.STDOUT, stdout=subprocess.PIPE, shell=True)
    pConn = Popen(r'watch -n .5 "date; netstat -an ' + \
        '| grep ESTABLISHED | wc -l >> output/%s.conn.csv"' % site, \
        stderr=subprocess.STDOUT, stdout=subprocess.PIPE, shell=True)
    browser.get(site_full) # Load page
    tend = time()
    
    print "Page load time: %.2f seconds" % (tend - tstart)
    sleep(SECONDS_PER_SITE)
    browser.close()

    kill((pConn, pStap))
    # hacky, but the above doesn't work
    os.system('killall watch')

  print "Terminated successfully!"

def kill(procs):
  for p in procs:
    p.terminate()
    try:
      os.killpg(p.pid, signal.SIGTERM)
    except OSError: pass
    p.wait()

main()

