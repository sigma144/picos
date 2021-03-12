ruleset wovyn_base {
  meta {
    name "Wovyn Base"
    use module sensor_profile alias profile
    use module io.picolabs.subscription alias subs
    use module io.picolabs.wrangler alias wrangler
    shares __testing
  }

  global {
    __testing = {
      "queries": [
        
      ],
      "events": [
        
      ]
    }
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
      threshold = profile:profile_info(){"threshold"}
      time = event:attrs{"timestamp"}
    }
    send_directive("Checking threshold violation", {
      "temperature": temperature,
      "threshold": threshold,
      "timestamp":time
    })
    fired {
      raise wovyn event "threshold_violation" attributes {
        "temperature":temperature,
        "timestamp":time
      }
      if (temperature > threshold);
    }
  }

  rule threshold_notification {
    select when wovyn threshold_violation
    pre {
      temperature = event:attrs{"temperature"}
      threshold = profile:profile_info(){"threshold"}
      time = event:attrs{"timestamp"}
    }
    event:send({
      "eci":ent:parent_wellKnown_eci,
      "eid":"threshold_violation",                  
      "domain":"sensor",
      "type":"threshold_violation",
      "attrs": {
        "message": <<"Hi Temp Alert at #{time}: Temperature #{temperature}F exceeds threshold of #{threshold}F>>
      }
    })
  }

  rule create_subscription {
    select when wovyn request_subscription
    always {
      raise wrangler event "subscription" attributes {
        "wellKnown_Tx":event:attrs{"manager_Rx"},
        "Rx_role":event:attrs{"Tx_role"}, "Tx_role":event:attrs{"Rx_role"},
        "name":event:attrs{"name"}, "channel_type":"subscription"
      }
    }
  }
}
