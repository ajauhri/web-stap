from selenium import webdriver
from time import time

SITES_LIST = 'data/top-100-sites.txt'
MAX_SITES = 1
SECONDS_PER_SITE = 15
MAX_TIMEOUT = 20000 # milliseconds

sites = open(SITES_LIST, 'r').read().split('\n')

for i, site in enumerate(sites[:MAX_SITES]):
  print "[%d of %d] Loading site: %s" % (i+1, MAX_SITES, site)
  browser = webdriver.Firefox() # Get local session of firefox
  tstart = time()
  browser.get("http://www.yahoo.com") # Load page
  tend = time()
  
  print "Page load time: %.2f seconds" % (tend - tstart)
  browser.close()

