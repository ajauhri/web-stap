#!/usr/bin/python
import subprocess
import os
import signal
from time import time,sleep
from subprocess import Popen
from collections import OrderedDict
from selenium import webdriver

SITES_LIST = 'data/top-100-sites.txt'
MEASURING_SCRIPT = 'stap stap_all.stp -G parent_id='
MOBILE_UA = 'Mozilla/5.0 (Linux; U; Android 2.3.3; en-us; HTC_DesireS_S510e Build/GRI40) ' + \
    'AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile'
SECONDS_PER_SITE = 150
MAX_SITES = 100

def main():
  if os.getuid() != 0:
    raise Exception('Not running as root')
    
  sites = open(SITES_LIST, 'r').read().split('\n')
  maxSites = min(MAX_SITES, len(sites))

  os.system('mkdir -p output')
  for i, site in enumerate(sites[:maxSites]):
    site_full = 'http://' + site
    print "[%d of %d] Loading site: %s" % (i+1, maxSites, site_full)
    for mobile in False, True:
      print 'Trying %s user agent...' % ('mobile' if mobile else 'default')
      profile = webdriver.FirefoxProfile()
      if mobile:
        profile.set_preference("general.useragent.override", MOBILE_UA)
        site += '-m'
      browser = webdriver.Firefox(profile)
      sleep(1)

      pStap = Popen('%s%s > output/%s-stap.csv' % (MEASURING_SCRIPT, str(os.getpid()), site), \
              stderr=subprocess.STDOUT, stdout=subprocess.PIPE, shell=True)
      pConn = Popen('watch -n .2 "bash measure-connections.sh >> ' \
          'output/%s-conns.csv"' % site, \
          stderr=subprocess.STDOUT, stdout=subprocess.PIPE, shell=True)
      browser.get(site_full) # Load page
      
      sleep(SECONDS_PER_SITE)
      timing = browser.execute_script("return performance.timing")
      timing = OrderedDict( 
        timeConnect = timing['connectEnd'] - timing['connectStart'],
        timeDomLoad = timing['domComplete'] - timing['domLoading'],
        timeDns = timing['domainLookupEnd'] - timing['domainLookupStart'],
        timeRedirect = timing['redirectEnd'] - timing['redirectStart'],
        timeResponse = timing['responseEnd'] - timing['responseStart']
      )
      print "Page load timers:"
      for i in timing: print ' * %s: %dms' % (i, timing[i])
      with open('output/%s-loadtime.csv' % site, 'w') as f:
        f.write(','.join(str(i) for i in timing.values()))

      kill((pConn, pStap))
      # hacky, but the above doesn't work sometimes
      os.system('killall watch')
      browser.close()
      # since the files are getting somewhat large, ~3-5MB, compress them
      os.system('bzip2 -f output/*.csv')
    print
  print "Terminated successfully!"

def kill(procs):
  for p in procs:
    p.terminate()
    try:
      os.killpg(p.pid, signal.SIGTERM)
    except OSError: pass
    p.wait()

main()

