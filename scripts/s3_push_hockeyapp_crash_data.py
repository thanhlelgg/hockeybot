#!/usr/bin/env python3
# encoding: utf-8

import os
import datetime
import requests
import sys
import util


############### GLOBAL ENVS ###############
HOCKEYAPP_URL = "https://rink.hockeyapp.net/api/2/apps/"

try:
  TOP_VERSION = os.environ['TOP_VERSION']
except KeyError:
  print("Please set the environment variable TOP_VERSION")
  sys.exit(1)

try:
  HOCKEYAPP_TOKEN = os.environ['HOCKEYAPP_TOKEN']
except KeyError:
  print("Please set the environment variable HOCKEYAPP_TOKEN")
  sys.exit(1)

try:
  ACCESS_KEY = os.environ['ACCESS_KEY']
except KeyError:
  print("Please set the environment variable ACCESS_KEY")
  sys.exit(1)

try:
  ACCESS_SECRET_KEY = os.environ['ACCESS_SECRET_KEY']
except KeyError:
  print("Please set the environment variable ACCESS_SECRET_KEY")
  sys.exit(1)

try:
  AWS_REGION = os.environ['AWS_REGION']
except KeyError:
  print("Please set the environment variable AWS_REGION")
  sys.exit(1)

try:
  S3_BUCKET = os.environ['S3_BUCKET']
except KeyError:
  print("Please set the environment variable S3_BUCKET")
  sys.exit(1)


def get_hockeyapp_ids():
  app_ids = {}
  headers = {'x-hockeyapptoken': HOCKEYAPP_TOKEN}
  response = requests.request("GET", HOCKEYAPP_URL, headers=headers)
  jsonInfo = response.json()
  apps = jsonInfo['apps']

  for app in apps:
    app_ids[(app['public_identifier'])] = app['title']

  return app_ids


def get_hockeyapp_crash_data(app_id, app_name, num_of_top_version, date):
  hockeyapp_crash_data = ""
  url = "{}{}/statistics".format(HOCKEYAPP_URL, app_id)
  headers = {'x-hockeyapptoken': HOCKEYAPP_TOKEN}
  response = requests.request("GET", url, headers=headers)
  jsonInfo = response.json()

  if jsonInfo['status'] == 'success':
    app_versions = jsonInfo['app_versions']

    if app_versions != None:
      for index, app_version in enumerate(app_versions, start=1):
        data = "{},{},{},{},{}\n".format(app_name,
                                         app_version['shortversion'],
                                         app_version['version'],
                                         app_version['statistics']['crashes'],
                                         date)
        hockeyapp_crash_data += data

        if index > num_of_top_version - 1:
          break

  return hockeyapp_crash_data


def get_all_hockeyapps_crash_counts(date):
  hockeyapp_versions_crash_data = "hockeyapp_name,app_version,build_number,crash_total,date\n"
  app_ids = get_hockeyapp_ids()

  for app_key, app_value in app_ids.items():
    data = get_hockeyapp_crash_data(app_key, app_value, int(TOP_VERSION), date)

    if data != "":
      hockeyapp_versions_crash_data += data

  return hockeyapp_versions_crash_data



####################################
############### MAIN ###############
####################################
def run():
  date = datetime.datetime.now()
  filename = 'hockeyapp_version_crash_counts-{}.csv'.format(date.strftime("%Y%m%d"))
  data = get_all_hockeyapps_crash_counts(date)

  f = open(filename, 'wt', encoding='utf-8')
  f.write(data)
  f.close()

  if util.S3Service.upload_file(AWS_REGION, ACCESS_KEY, ACCESS_SECRET_KEY, S3_BUCKET, filename):
      print('File uploaded to S3.')
      os.remove(filename)
  else:
      print('The upload failed...')


if __name__ == '__main__':
  run()
