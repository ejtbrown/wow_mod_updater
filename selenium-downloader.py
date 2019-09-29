#!/usr/bin/env python3
from selenium import webdriver
import os
import time
import random

target_dir = os.environ['TEMP_STORAGE']
download_dir = os.sep.join([target_dir, 'dl'])
service_urls = {
    'curse_forge': "https://www.curseforge.com/wow/addons/{0}/download",
    'wow_ace': "https://www.wowace.com/projects/{0}/files/latest"
}

prefs = {"download.default_directory" : download_dir}
options = webdriver.ChromeOptions()
options.add_experimental_option("prefs",prefs)
options.binary_location = os.environ['CHROMIUM_EXECUTABLE']
driver = webdriver.Chrome(options=options)

try:
    with open(os.environ['MOD_LIST']) as mod_list:
        for line in mod_list.readlines():
            # Wait a random period of time to avoid the appearance
            # of a pattern of automated downloads
            time.sleep(random.randint(2, 6))

            mod = line.split()
            if len(mod) == 0:
                continue

            if mod[0] not in service_urls:
                print("ERROR: Unknown service " + mod[0], flush=True)
                continue

            url = service_urls[mod[0]].format(mod[1])

            print("Downloading " + str(url), flush=True)
            driver.get(url)
            dl_delay = random.randint(5, 15)
            time.sleep(dl_delay)

            dir_list = []
            wait_count = 0
            while len(dir_list) == 0:
                dir_list = os.listdir(download_dir)
                time.sleep(1)

                # Make sure that we wait no longer than
                # three minutes for this download
                wait_count += 1
                if wait_count == 180:
                    break

            if len(dir_list) == 0:
                print("ERROR: " + url + " yielded no download", flush=True)
                continue

            dl_file = dir_list[0]
            ext = dl_file[dl_file.rfind('.'):]
            out_file = "{0}-{1}{2}".format(mod[0], mod[1], ext)

            os.rename(
                os.sep.join([download_dir, dl_file]),
                os.sep.join([target_dir, out_file])
            )
            print(out_file + " successfully download from " + url, flush=True)

except Exception as ee:
    print("ERROR: Python exception " + str(ee), flush=True)

finally:
    driver.quit()
