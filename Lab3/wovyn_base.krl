ruleset wovyn_base {
  meta {
    name "Wovyn Base"
    use module twilio_api alias api
    shares __testing
    configure using
      alert_number = ""
  }
   
  global {
    __testing = {
      "queries": [
        
      ],
      "events": [
        
      ]
    }

    temperature_threshold = 100 //Fahrenheit
  }

  rule process_heartbeat {
    select when wovyn heartbeat genericThing re#(.+)#
    pre {
      temp = event:attrs{"genericThing"}{"data"}{"temperature"}.klog("Reading temperature object:")
    }
    send_directive("say", {"something:": "Heartbeat!"})
    fired {
      raise wovyn event "new_temperature_reading" attributes {
        "temperature":temp,
        "timestamp":time:now()
      }
    }
  }

  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      temperature = event:attrs{"temperatureF"}.klog("Temperature in F:")
    }
    fired {
      raise wovyn event "threshold_violation" attributes {}
      if (temperature > temperature_threshold);
    }
  }

  rule threshold_notification {
    select when wovyn temperature_violation
    pre {
      temperature = math:round(event:attrs{"temperature"}).klog("Exceeded threshold: ")
      time = event:attrs{"timestamp"}
    }
    fired {
      //raise test event send attributes {
      //  "to": alert_number,
      //  "message": <<"Hi Temp Alert at #{time}: Temperature #{temperature}F exceeds threshold of #{threshold}F>>
      //}
    }
  }
}
