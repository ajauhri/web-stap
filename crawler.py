#!/usr/bin/python
import subprocess
from subprocess import Popen
import os
import signal
from time import time,sleep

from selenium import webdriver

SITES_LIST = 'data/top-10-sites.txt'
MEASURING_SCRIPT1 = './nettop.stp'
MEASURING_SCRIPT2 = './syscall.stp'
MOBILE_UA = 'Mozilla/5.0 (Linux; U; Android 2.3.3; en-us; HTC_DesireS_S510e Build/GRI40) ' + \
    'AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile'
MAX_SITES = 1
SECONDS_PER_SITE = 150

def main():
  if os.getuid() != 0:
    raise Exception('Not running as root')

  sites = open(SITES_LIST, 'r').read().split('\n')

  os.system('mkdir -p output')
  for mobile in True, False:
    for i, site in enumerate(sites[:MAX_SITES]):
      os.system('rm -f output/%s*' % site)
      site_full = 'http://' + site
      print "[%d of %d] Loading site: %s" % (i+1, MAX_SITES, site_full)
      profile = webdriver.FirefoxProfile()
      if mobile:
        profile.set_preference("general.useragent.override", MOBILE_UA)
        site += '-m'
      browser = webdriver.Firefox(profile)
      sleep(1)

      tstart = time()
      pStap1 = Popen('%s > output/%s-stap-packets.csv' % (MEASURING_SCRIPT1, site), \
          stderr=subprocess.STDOUT, stdout=subprocess.PIPE, shell=True)
      pStap2 = Popen('%s > output/%s-stap-syscalls.csv' % (MEASURING_SCRIPT2, site), \
          stderr=subprocess.STDOUT, stdout=subprocess.PIPE, shell=True)
      pConn = Popen(r'watch -n .5 "date; netstat -an ' + \
          '| grep ESTABLISHED | wc -l >> output/%s-conns.csv"' % site, \
          stderr=subprocess.STDOUT, stdout=subprocess.PIPE, shell=True)
      browser.get(site_full) # Load page
      tend = time()
      
      loadTime = tend - tstart
      open('output/%s.loadtime', 'w').write(str(loadTime))
      print "Page load time: %.2f seconds" % loadTime
      sleep(SECONDS_PER_SITE)
      browser.close()

      kill((pConn, pStap1, pStap2))
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

