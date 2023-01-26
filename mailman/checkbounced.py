#!/usr/bin/python3

# A script to download the suppression list from mailgun, and then parse the results.
#
# It will generate the following output:
# page1.json, page2.json, page3.json, etc. These contain the raw results from the mailgun api.
#
# list_over_quota.txt	Emails that are "over quota", from more than 6 months ago.
# list_over_quota_recent.txt   Emails that are "over quota", from less than 6 months ago.
# list_bounces.txt	All hard bounces for other reasons, not including quota errors.
#
# list_bounces.txt should be purged from the mailing list.
# The quota emails may be given another chance.
# But if they continue to appear in these list they should also be purged.

import json
import pytz
from datetime import *
from dateutil.parser import parse
from dateutil.relativedelta import *
import os
import requests
from requests.auth import HTTPBasicAuth

#
# Section 1: Download
#

apikey = os.getenv('MAILGUN_API_KEY')

if not apikey:
    print("Please set the environment variable: export MAILGUN_API_KEY= and then rerun the script.")
    exit()

nextpage="https://api.mailgun.net/v3/lists.boost.org/bounces?limit=1000"
page=1
allpages=[]

while nextpage:
    print("Downloading " + nextpage)
    r = requests.get(nextpage, allow_redirects=True, auth=HTTPBasicAuth('api', apikey))
    content = r.content
    jsoncontent=json.loads(content)
    prettycontent = json.dumps(jsoncontent, indent=4, separators=(',', ': '), sort_keys=True)
    pagename = "page" + str(page) + ".json"
    allpages.append(pagename)
    filehandle = open(pagename, 'w')
    filehandle.write(prettycontent)
    filehandle.close()
    nextpage=jsoncontent['paging']['next']
    print("Next page is " + nextpage + "\n")
    if not "page=next" in nextpage:
        nextpage="" 
    page = page + 1

print("allpages:")
print(allpages)

#
# Section 2: Parse
#

now = datetime.now(pytz.timezone('UTC'))
threshold = now - relativedelta(months=6) 

list_bounces = open("list_bounces.txt", "w")  
list_over_quota = open("list_over_quota.txt", "w")  
list_over_quota_recent = open("list_over_quota_recent.txt", "w")  

for page in allpages:
    print("Processing " + page)
    f = open(page)
    data = json.load(f)
    if data['items']:
        for item in data['items']:
            created_at = parse(item['created_at'])
            if (item['code'] == '552') and ("quota" in item['error'].lower()):
                if created_at > threshold:
                    list_over_quota_recent.write(item['address'] + "\n")
                else:
                    list_over_quota.write(item['address'] + "\n")
            else:
                list_bounces.write(item['address'] + "\n")
  
    f.close()

list_bounces.close()
list_over_quota.close()
list_over_quota_recent.close()
