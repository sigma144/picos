ruleset lab2 {
  meta {
    name "Lab 2"
    use module twilio_api alias api
      with
        sid = meta:rulesetConfig//{"sid"}
        authToken = meta:rulesetConfig//{"auth_token"}
        from_number = meta:rulesetConfig//{"phone_number"}
    shares __testing, lastResponse
  }
   
  global {
    __testing = {
      "queries": [],
      "events": [
        {"domain": "test", "name": "send", "attrs":["to", "message"]}
      ]
    }
    lastResponse = function() {
      {}.put(ent:lastTimestamp,ent:lastResponse)
    }
  }

  rule send_text_message {
    select when test send
    pre {
      to = event:attrs{"to"}
      msg = event:attrs{"message"}
    }
    api:sendTextMessage(to, msg) setting(response)
    fired {
      ent:lastResponse := response
      ent:lastTimestamp := time:now()
    }
  }
}
