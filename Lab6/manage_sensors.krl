ruleset manage_sensors {
    meta {
        name "Temperature Store"
        shares __testing
        use module io.picolabs.wrangler alias wrangler
    }
    
    global {
        __testing = {
            "queries": [

            ],
            "events": [
                {"domain": "sensor", "name": "new_sensor", "attrs":["name", "alert_number"]},
                {"domain": "sensor", "name": "unneeded_sensor", "attrs":["name"]},
            ]
        }
        github_path = "https://raw.githubusercontent.com/sigma144/picos/master/"
        sensors = function() {
            ent:sensors
        }
        temps = function() {
            temp_map = ent:sensors.map(function(name,eci) {
                wrangler:picoQuery(eci,"temperature_store","temperatures",{})
            })
            temp_array = temp_map.values().reduce(function(a,b){a + b})
            temp_array
        }
        installRuleset = defaction(eci, rulesetURI) {
            event:send( {
                "eci": eci,
                "eid": "install-ruleset-"+rulesetURI,
                "domain": "wrangler", "type": "install_ruleset_request",
                "attrs": {
                    "url": rulesetURI
                }
            })
        }
        threshold_default = 80
    }

    
    rule intialization {
        select when wrangler ruleset_added where event:attrs{"rids"} >< ctx:rid
        if ent:sensors.isnull() then noop()
        fired {
            ent:sensors := {}
        }
    }

    rule new_sensor {
        select when sensor new_sensor
        pre {
            name = event:attrs{"name"}
            alert_number = event:attrs{"alert_number"}
        }
        if sensors{name} then send_directive("Error", "A sensor with name '"+name+"' already exists.")
        fired {
            raise wrangler event "new_child_request" attributes {
                "name": name,
                "alert_number": alert_number,
                "backgroundColor": "#ff69b4"
            }
        }
    }
    rule install_wovyn_base {
        select when wrangler new_child_created
        installRuleset(event:attrs{"eci"}, github_path+"Lab3/wovyn_base.krl")
    }
    rule install_temperature_store {
        select when wrangler new_child_created
        installRuleset(event:attrs{"eci"}, github_path+"Lab4/temperature_store.krl")
    }
    rule install_sensor_profile {
        select when wrangler new_child_created
        installRuleset(event:attrs{"eci"}, github_path+"Lab5/sensor_profile.krl")
    }
    rule install_sensor_emulator {
        select when wrangler new_child_created
        installRuleset(event:attrs{"eci"}, "https://raw.githubusercontent.com/windley/temperature-network/main/io.picolabs.wovyn.emitter.krl")
    }

    rule store_sensor {
        select when wrangler new_child_created
        pre {
            sensor_eci = event:attrs{"eci"}
            name  = event:attrs{"name"}
            alert_number = event:attrs{"alert_number"}
        }
        fired {
          ent:sensors{name} := sensor_eci
          raise sensor event "profile_updated" attributes {
            "name":name,
            "alert_number":alert_number,
            "threshold":threshold_default
          }
        }
    }

    rule delete_sensor {
        select when sensor unneeded_sensor
        pre {
            name = event:attrs{"name"}
        }
        if ent:sensors >< name then noop()
        fired {
            raise wrangler event "child_deletion_request"
                attributes {"eci": ent:sensors{name} };
            clear ent:sensors{name}
        }
    }
}