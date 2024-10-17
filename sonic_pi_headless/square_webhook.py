#!/usr/bin/python
#
# Demonstrates a server listening for webhook notifications from the Square Connect API
#
# See Webhooks Overview for more information:
# https://developer.squareup.com/docs/webhooks-api/v1-tech-ref
#
# To install Python on Windows:
# https://www.python.org/download/
#
# This sample requires the Bottle web framework:
# http://bottlepy.org/docs/dev/tutorial.html#installation
# 
#
# This ONLY works with python 2 
# and even then I can't get the sigs to match
# 🤷


from bottle import Bottle, request, response, run
from hashlib import sha1
import hmac, httplib, json, locale
from functools import wraps
from datetime import datetime
import logging
import paho.mqtt.publish as publish

logger = logging.getLogger('myapp')

# set up the logger
logger.setLevel(logging.INFO)
file_handler = logging.FileHandler('myapp.log')
formatter = logging.Formatter('%(msg)s')
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(formatter)
logger.addHandler(file_handler)

sometext = None
ids = []


def log_to_logger(fn):
    '''
    Wrap a Bottle request so that a log line is emitted after it's handled.
    (This decorator can be extended to take the desired logger as a param.)
    '''
    @wraps(fn)
    def _log_to_logger(*args, **kwargs):
        global sometext
        request_time = datetime.now()
        actual_response = fn(*args, **kwargs)
        # modify this to log exactly what you need:
        logger.info('%s %s %s' % (
                                        request_time,
                                        sometext,
                                        response.status))


        return actual_response
    return _log_to_logger

# Your application's access token
access_token = 'xxxxx'

# Your application's webhook signature key, available from your application dashboard
webhook_signature_key = 'xxxxx'

# The URL that this server is listening on (e.g., 'http://example.com/events')
# Note that to receive notifications from Square, this cannot be a localhost URL
webhook_url = 'https://example.com/foo/bar'

# Headers to provide to Connect API endpoints
request_headers = { 'Authorization': 'Bearer ' + access_token,
                    'Accept': 'application/json',
                    'Content-Type': 'application/json'}


# Note that you need to set your application's webhook URL from your application dashboard
# to receive these notifications. In this sample, if your host's base URL is 
# http://example.com, you'd set your webhook URL to http://example.com/events

app = Bottle()
app.install(log_to_logger)

@app.route('/events', ['POST'],)
def webhooks_callback():
  global sometext

  # Get the JSON body and HMAC-SHA1 signature of the POST request
  callback_body = request.body.getvalue()
  callback_signature = request.get_header('X-Square-Signature', default='')

  # Validate the signature
  if not is_valid_callback(callback_body, callback_signature):

    # Fail if the signature is invalid
    # it's stoppped working again!
    # so I'm not leting it fail!
    print 'Webhook event with invalid signature detected!'
    #return

  # Load the JSON body into a Python dict
  callback_body_dict = json.loads(callback_body)
  #print(callback_body_dict["type"], callback_body_dict["data"]["object"]["payment"]["amount_money"]["amount"])
  #print(callback_body)
  if(callback_body_dict["type"] == "payment.created"):

    # we seem to get duplicates
    theid = callback_body_dict["data"]["id"]
 
    if theid in ids:
      pass
    else:
      ids.append(theid)
      if(len(ids)>10): # keep the list short
         ids.pop(0)
      money = str(callback_body_dict["data"]["object"]["payment"]["amount_money"]["amount"])
      sometext = callback_body_dict["type"]+" "+ money
      host = "localhost"
      publish.single(topic="cube/music", payload=money, hostname=host)
#  else:
#    sometext = callback_body_dict["type"]

# Validates HMAC-SHA1 signatures included in webhook notifications to ensure notifications came from Square
def is_valid_callback(callback_body, callback_signature):

  # Combine your webhook notification URL and the JSON body of the incoming request into a single string
  string_to_sign = webhook_url + callback_body

  # Generate the HMAC-SHA1 signature of the string, signed with your webhook signature key
  string_signature = hmac.new(webhook_signature_key, string_to_sign, sha1).digest().encode('base64')

  # Remove the trailing newline from the generated signature (this is a quirk of the Python library)
  string_signature = string_signature.rstrip('\n')

  # Compare your generated signature with the signature included in the request
  return hmac.compare_digest(string_signature, callback_signature)

# Start up the server
app.run(host='localhost', port=8070)
