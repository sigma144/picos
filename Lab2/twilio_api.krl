ruleset twilio_api {
  meta {
    name "Twilio API Module"
    shares __testing
    provides getTexts, sendTextMessage
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

    getTexts = function() {
      auth = {"username":sid, "password":authToken}
      response = http:get(<<#{base_url}/movie/popular>>, auth=auth)
      response{"content"}.decode()
    }

    sendTextMessage = defaction(to, message) {
      //headers = {"content-type": "application/json"}
      body = {"To":"+17174502511","From":from_number, "Body":"Testing"}
      auth = {"username":sid, "password":authToken}
      http:post(<<#{base_url}/Accounts/#{sid}/Messages.json>>, 
        auth=auth, qs=body) setting(response)
      return response
    }
  }
}
