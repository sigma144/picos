ruleset manage_sensors {
    meta {
        name "Temperature Store"
        shares __testing
    }
    global {
        __testing = {
            "queries": [

            ],
            "events": [

            ]
        }
        eci = ""
        sensors = function() {
            ent:sensors
        }
        /*
        temps = function() {
            foreach ent:sensors setting (name,eci)
            response = wrangler:picoQuery(eci,"temperature_store","temperatures",{})
            if answer{"error"}.isnull()
        }*/
        installRuleset = defaction(rulesetURI, rid) {
            event:send( {
                "eci": eci,
                "eid": "install-ruleset-"+rid,
                "domain": "wrangler", "type": "install_ruleset_request",
                "attrs": {
                    "absoluteURL": rulesetURI,
                    "rid": rid,
                    "config": {}
                }
            })
        }
        threshold_default = 80
    }

    
    rule intialization {
        select when wrangler ruleset_added where event:attrs{"rids"} >< ctx:rid
        if ent:owners.isnull() then noop()
        fired {
            ent:sensors := {}
        }
    }

    rule new_sensor {
        select when sensor new_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
        }
        if sensors{sensor_id} then send_directive("Error", "A sensor with name '"+sensor_id+"' already exists.")
        fired {
            raise wrangler event "new_child_request" attributes {
                "name": sensor_id,
                "backgroundColor": "#ff69b4"
            }
        }
    }

    rule install_temperature_store {
        select when wrangler new_child_created
        installRuleset(event:attrs{"eci"}, "temperature_store")
    }
    rule install_wovyn_base {
        select when wrangler new_child_created
        installRuleset(event:attrs{"eci"}, "wovyn_base")
    }
    rule install_sensor_profile {
        select when wrangler new_child_created
        installRuleset(event:attrs{"eci"}, "sensor_profile")
    }
    rule install_sensor_emulator {
        select when wrangler new_child_created
        installRuleset(event:attrs{"eci"}, "io.picolabs.wovyn.emitter")
    }

    rule store_sensor {
        select when wrangler new_child_created
        pre {
            sensor_eci = event:attrs{"eci"}
            sensor_id = event:attrs{"sensor_id"}
            alert_number = event:attrs{"alert_number"}
        }
        fired {
          ent:sensors{sensor_id} := sensor_eci
          raise sensor event "profile_updated" attributes {
            "name":sensor_id,
            "alert_number":alert_number,
            "threshold":threshold_default
          }
        }
      }

    rule delete_sensor {
        select when sensor unneeded_sensor
        pre {
            sensor_id = event:attrs{"sensor_id"}
        }
        if ent:sensors >< sensor_id then noop()
        fired {
            raise wrangler event "child_deletion_request"
                attributes {"eci": ent:sensors{sensor_id} };
            clear ent:sensors{sensor_id}
        }
    }
}