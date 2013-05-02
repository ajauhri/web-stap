#!/usr/bin/python
import subprocess
import os
import signal
from time import time,sleep
from subprocess import Popen
from collections import OrderedDict
from selenium import webdriver
from selenium.common.exceptions import WebDriverException

SITES_LIST = 'data/sites-1m-pruned.csv'
MEASURING_SCRIPT = 'stap stap_all.stp'
MOBILE_UA = 'Mozilla/5.0 (Linux; U; Android 2.3.3; en-us; HTC_DesireS_S510e Build/GRI40) ' \
    'AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile'
SECONDS_PER_SITE = 150
MAX_SITES = 1e6
START_INDEX = 259

def main():
  if os.getuid() != 0:
    raise Exception('Not running as root')
    
  sites = open(SITES_LIST, 'r').read().split('\n')
  maxSites = min(MAX_SITES, len(sites))

  os.system('mkdir -p output_corr')
  for i, site in enumerate(sites[START_INDEX:maxSites]):
    site_full = 'http://' + site
    print "[%d of %d] Loading site: %s" % (i+1+START_INDEX, maxSites, site_full)
    for mobile in False, True:
      print 'Trying %s user agent...' % ('mobile' if mobile else 'default')
      profile = webdriver.FirefoxProfile()
      if mobile:
        profile.set_preference("general.useragent.override", MOBILE_UA)
        site += '-m'
      browser = webdriver.Firefox(profile)
      browser.set_page_load_timeout(SECONDS_PER_SITE)
      browser.set_script_timeout(3)
      browserPID = browser.binary.process.pid
      sleep(5)
      cmd = '%s -G parent_id=%s -G browser_id=%s > output_corr/%s-stap.csv' % \
          (MEASURING_SCRIPT, str(os.getpid()), str(browserPID), site)
      print cmd
      pStap = Popen(cmd, \
          stderr=subprocess.STDOUT, stdout=subprocess.PIPE, shell=True)
      pConn = Popen('watch -n .2 "bash measure-connections.sh >> ' \
          'output_corr/%s-conns.csv"' % site, \
          stderr=subprocess.STDOUT, stdout=subprocess.PIPE, shell=True)
      def close(signal, frame):
        print 'Caught sigint--terminating.'
        kill((pConn, pStap))
        
      signal.signal(signal.SIGINT, close)
      sleep(5)
      try:
        browser.get(site_full) # Load page
      except WebDriverException as e:
        print str(e)
        kill((pConn, pStap))
        browser.quit()
        continue
      
      sleep(SECONDS_PER_SITE)
      try:
        timing = browser.execute_async_script(
            "arguments[arguments.length - 1](performance.timing)")
        timing = OrderedDict( 
            timeConnect = timing['connectEnd'] - timing['connectStart'],
            timeDomLoad = timing['domComplete'] - timing['domLoading'],
            timeDns = timing['domainLookupEnd'] - timing['domainLookupStart'],
            timeRedirect = timing['redirectEnd'] - timing['redirectStart'],
            timeResponse = timing['responseEnd'] - timing['responseStart']
        )
        print "Page load timers:"
        for i in timing: print ' * %s: %dms' % (i, timing[i])
        with open('output_corr/%s-loadtime.csv' % site, 'w') as f:
          f.write(','.join(str(i) for i in timing.values()))
      except (WebDriverException, TypeError) as e:
        print 'Javascript timer error: ' + str(e)
      kill((pConn, pStap))
      browser.quit()
      # since the files are getting somewhat large, ~3-5MB, compress them
      os.system('bzip2 -f output_corr/*.csv')
    print
  print "Terminated successfully!"

def kill(procs):
  for p in procs:
    try:
      p.terminate()
      os.killpg(p.pid, signal.SIGTERM)
    except OSError: pass
    p.wait()
  # hacky, but the above doesn't work sometimes
  os.system('killall watch')

main()

