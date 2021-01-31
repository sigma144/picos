ruleset twilio_api {
  meta {
    name "Twilio API Module"
    shares __testing
    provides sendTextMessage, messages
    configure using
      from_number = ""
      sid = ""
      authToken = ""
  }
   
  global {
    __testing = {
      "queries": [],
      "events": [] 
    }

    base_url = "https://api.twilio.com/2010-04-01"

    messages = function(msg_sid = null, to = null, from_number = null, page_size = null) {
      params = {"To":to, "From":from_number}
      qs = {"PageSize":page_size}
      auth = {"username":sid, "password":authToken}
      response = http:get(msg_sid => <<#{base_url}/Accounts/#{sid}/Messages/#{msg_sid}.json>> |  <<#{base_url}/Accounts/#{sid}/Messages.json>>,
        params=params, qs=qs, auth=auth)
      response{"content"}.decode()
    }

    sendTextMessage = defaction(to, message) {
      params = {"To":to, "From":from_number, "Body":message}
      auth = {"username":sid, "password":authToken}
      http:post(<<#{base_url}/Accounts/#{sid}/Messages.json>>, 
        auth=auth, form=params) setting(response)
      return response
    }
  }
}
