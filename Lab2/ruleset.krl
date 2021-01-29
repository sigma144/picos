ruleset lab2 {
  meta {
    name "Lab 2"
    use module twilio_api alias api
      with
        sid = meta:rulesetConfig{"sid"}
        authToken = meta:rulesetConfig{"auth_token"}
        from = meta:rulesetConfig{"phone_number"}
    shares __testing, getTexts, sendTextMessage, lastResponse
  }
   
  global {
    __testing = {
      "queries": [],
      "events": [
        {"domain": "test", "name": "send", "attrs":["to", "message"]},
        {"domain": "test", "name": "response"}
      ]
    }
    getTexts = function() {
      api:getTexts()
    }
    sendTextMessage = function(from, to, msg) {
      //api:sendTextMessage(from, to, msg)
      "Okay"
    }
    lastResponse = function() {
      {}.put(ent:lastTimestamp,ent:lastResponse)
    }
  }

  rule send_text_message {
    select when test send
    pre {
      to = event:attr("to")
      msg = event:attr("message")
    }
    sendTextMessage(from, to, msg) setting(response)
    fired {
      ent:lastResponse := response
      ent:lastTimestamp := time:now()
    }
  }
  rule get_status {
    select when test response
    lastResponse()
  }
}
