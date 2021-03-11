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
        {"domain": "test", "name": "testing", "attrs":[]},
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

  rule pico_ruleset_added {
    select when wrangler ruleset_installed or test testing
      name re#(.+)#
      wellKnown_eci re#(.+)#
      setting(name,parent_wellKnown_eci)
      where event:attrs{"rids"} >< meta:rid
    //pre {
    //    name = event:attrs{"name"}
    //    wellKnown_eci = event:attrs{"wellKnown_eci"}
    //}
    send_directive("Initialization", {"name":name, "wellKnown_eci":wellKnown_eci, "attrs":event:attrs})
    always {
      raise sensor event "request_channel" attributes {
        "name": name,
        "wellKnown_eci": wellKnown_eci
      }
    }
  }

  rule identify_subscription_channel {
    select when sensor request_channel
      name re#(.+)#
      wellKnown_eci re#(.+)#
      setting(name,parent_wellKnown_eci)
    pre {
      wellKnown_eci = subs:wellKnown_Rx(){"id"}
      parent_eci = wrangler:parent_eci()
    }
    event:send({"eci":parent_eci,
      "domain": "sensor", "type": "identify",
      "attrs": {
        "name": name,
        "wellKnown_eci": wellKnown_eci
      }
    })
    always {
      ent:name := name
      ent:parent_wellKnown_eci := parent_wellKnown_eci
    }
  }

  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    pre {
      my_role = event:attrs{"Rx_role"}
      their_role = event:attrs{"Tx_role"}
    }
    if my_role=="manager" && their_role=="temperature_sensor" then noop()
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
      ent:subscriptionTx := event:attrs{"Tx"}
    } else {
      raise wrangler event "inbound_rejection"
        attributes event:attrs
    }
  }
}
