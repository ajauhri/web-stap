import subprocess 
import os
from time import time

from selenium import webdriver

SITES_LIST = 'data/top-100-sites.txt'
MEASURING_SCRIPT = './nettop.stp'
MAX_SITES = 1
SECONDS_PER_SITE = 15
MAX_TIMEOUT = 20000 # milliseconds

sites = open(SITES_LIST, 'r').read().split('\n')

os.system('mkdir -p output')

for i, site in enumerate(sites[:MAX_SITES]):
  site_full = 'http://' + site
  print "[%d of %d] Loading site: %s" % (i+1, MAX_SITES, site_full)
  browser = webdriver.Firefox() # Get local session of firefox

  tstart = time()
  pStap = Popen('%s > output/%s.stap.csv' % (MEASURING_SCRIPT, site), shell=True)
  pConn = Popen('watch -n .5 "echo `date +%F-%T.%N`,`netstat -an ' \
      '| grep ESTABLISHED | wc -l` > output/%s.conn.csv"' % site, shell=True)
  browser.get(site_full) # Load page
  tend = time()
  
  print "Page load time: %.2f seconds" % (tend - tstart)
  browser.close()

