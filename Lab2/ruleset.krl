ruleset lab2 {
  meta {
    name "Lab 2"
    use module twilio_api alias api
      with
        sid = meta:rulesetConfig{"sid"}
        authToken = meta:rulesetConfig{"auth_token"}
        from_number = meta:rulesetConfig{"phone_number"}
    shares __testing, lastResponse
  }
   
  global {
    __testing = {
      "queries": [
        {"name": "lastResponse"}
      ],
      "events": [
        {"domain": "test", "name": "send", "attrs":["to", "message"]},
        {"domain": "test", "name": "read", "attrs":["to", "from"]}
      ]
    }
    lastResponse = function() {
      {}.put(ent:lastTimestamp,ent:lastResponse)
    }
  }

  rule send_text_message {
    select when test send
    pre {
      to = event:attrs{"to"}.klog("Send to: ")
      msg = event:attrs{"message"}.klog("Message: ")
    }
    api:sendTextMessage(to, msg) setting(response)
    fired {
      ent:lastResponse := response
      ent:lastTimestamp := time:now()
    }
  }

  rule get_messages {
    select when test read
    pre {
      to = event:attrs{"to"}.klog("Sent to: ")
      from_number = event:attrs{"from"}.klog("Sent from: ")
    }
    send_directive("result", {"response": api:messages(to, from_number)})
  }
}
