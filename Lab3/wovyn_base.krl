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

    temperature_threshold = 78 //Fahrenheit
  }

  rule process_heartbeat {
    select when wovyn heartbeat genericThing re#(.+)#
    pre {
      temperature = event:attrs{"genericThing"}{"data"}{"temperature"}[0].klog("Reading temperature object")
    }
    send_directive("Temperature Reading", temperature)
    fired {
      raise wovyn event "new_temperature_reading" attributes {
        "temperature":temperature,
        "timestamp":time:now()
      }
    }
  }

  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      temperature = event:attrs{"temperature"}{"temperatureF"}.klog("Temperature in F")
      th = temperature_threshold.klog("Threshold")
      time = event:attrs{"timestamp"}
    }
    send_directive("Checking threshold violation", {
      "temperature": temperature,
      "threshold": temperature_threshold,
      "timestamp":time
    })
    fired {
      raise wovyn event "threshold_violation" attributes {
        "temperature":temperature,
        "timestamp":time
      }
      if (temperature > temperature_threshold);
    }
  }

  rule threshold_notification {
    select when wovyn threshold_violation
    pre {
      temperature = math:round(event:attrs{"temperature"}).klog("Exceeded threshold")
      time = event:attrs{"timestamp"}
    }
    send_directive("Threshold exceeded! Sending notification", {
      "phone-no":alert_number,
      "timestamp":time
    })
    fired {
      raise test event "send" attributes {
        "to": alert_number,
        "message": <<"Hi Temp Alert at #{time}: Temperature #{temperature}F exceeds threshold of #{temperature_threshold}F>>
      }
    }
  }
}
