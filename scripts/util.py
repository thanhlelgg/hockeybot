#!/usr/bin/env python3
# encoding: utf-8

import boto3
from boto3.s3.transfer import S3Transfer

class S3Service :
  
  S3_KEYS = ['dev', 'beta', 'prod']

  def upload_file(aw_region, access_key, access_secret_key, s3_bucket, filename):
    try:
      for key in S3Service.S3_KEYS:
        transfer = S3Transfer(boto3.client('s3',
                                           aw_region,
                                           aws_access_key_id=access_key,
                                           aws_secret_access_key=access_secret_key))
        transfer.upload_file(filename, s3_bucket, '{}/{}'.format(key, filename))

      return True
    except Exception as e:
      print('There was an exception uploading to S3:\n{}'.format(e))
      return False
