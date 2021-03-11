ruleset manage_sensors {
    meta {
        name "Temperature Store"
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
        shares __testing, sensors, temps
    }

    global {
        __testing = {
            "queries": [
                {"name": "sensors"},
                {"name": "temps"}
            ],
            "events": [
                {"domain": "sensor", "name": "new_sensor", "attrs":["name", "alert_number"]},
                {"domain": "sensor", "name": "unneeded_sensor", "attrs":["name"]},
                {"domain": "sensor", "name": "introduce_pico", "attrs":["name", "eci"]},
            ]
        }
        github_path = "https://raw.githubusercontent.com/sigma144/picos/master/"
        sensors = function() {
            ent:sensors
        }
        temps = function() {
            temp_map = ent:sensors.map(function(eci,name) {
                peerSubs = subscription:established("Id", eci{"wellKnown_eci"})
                sub = peerSubs.head()
                peerChannel = sub{"Tx"}
                peerHost = (sub{"Tx_host"} || meta:host)
                wrangler:skyQuery(peerChannel, "temperature_store","temperatures",{}, peerHost)
            })
            temp_map
        }
        installRuleset = defaction(name, eci, rulesetURI) {
            event:send({
                "eci": eci,
                "eid": "install-ruleset-"+rulesetURI,
                "domain": "wrangler", "type": "install_ruleset_request",
                "attrs": {
                    "url": rulesetURI,
                    "name": name,
                    "wellKnown_eci":ent:wellKnown_eci
                }
            })
        }
        threshold_default = 81
    }

    
    rule intialization {
        select when wrangler ruleset_added where event:attrs{"rids"} >< ctx:rid
        if ent:sensors.isnull() then noop()
        fired {
            ent:sensors := {}
            ent:wellKnown_eci := subs:wellKnown_Rx(){"id"}
        }
    }

    rule new_sensor {
        select when sensor new_sensor
        pre {
            name = event:attrs{"name"}
            alert_number = event:attrs{"alert_number"}
        }
        if sensors{name} then send_directive("Error", "A sensor with name '"+name+"' already exists.")
        notfired {
            raise wrangler event "new_child_request" attributes {
                "name": name,
                "alert_number": alert_number,
                "backgroundColor": "#ff69b4",
                "wellKnown_eci":ent:wellKnown_eci
            }
        }
    }

    rule install_sensor_profile {
        select when wrangler new_child_created
        installRuleset(event:attrs{"name"}, event:attrs{"eci"}, github_path+"Lab7/sensor_profile.krl")
    } 
    rule install_temperature_store {
        select when wrangler new_child_created
        installRuleset(event:attrs{"name"}, event:attrs{"eci"}, github_path+"Lab4/temperature_store.krl")
    }
    rule install_wovyn_base {
        select when wrangler new_child_created
        installRuleset(event:attrs{"name"}, event:attrs{"eci"}, github_path+"Lab7/wovyn_base.krl")
    }
    rule install_sensor_emulator {
        select when wrangler new_child_created
        installRuleset(event:attrs{"name"}, event:attrs{"eci"}, "https://raw.githubusercontent.com/windley/temperature-network/main/io.picolabs.wovyn.emitter.krl")
    }

    rule store_sensor {
        select when wrangler new_child_created
        pre {
            sensor_eci = event:attrs{"eci"}
            name  = event:attrs{"name"}
            alert_number = event:attrs{"alert_number"}
        }
        event:send({
            "eci": sensor_eci,
            "eid": "profile-update-"+name,
            "domain": "sensor", "type": "profile_updated",
            "attrs": {
                "name":name,
                "alert_number":alert_number,
                "threshold":threshold_default
                }
            })
        always {
          ent:sensors{[name,"eci"]} := sensor_eci
        }
    }

    rule introduce_pico {
        select when sensor introduce_pico
            name re#(.+)#
            eci re#(.+)#
        setting(name,eci)
        event:send({"eci":eci,
        "domain": "sensor", "type": "request_channel",
        "attrs": {
            "name": name,
            "wellKnown_eci": ent:wellKnown_eci
        }
        })
        always {
            ent:sensors{[name,"eci"]} := event:attrs{"eci"}
        }
    }

    rule accept_wellKnown {
        select when sensor identify
          name re#(.+)#
          wellKnown_eci re#(.+)#
          setting(name,wellKnown_eci)
        send_directive("Accept well known", {"name": name, "wellKnown":wellKnown_eci})
        fired {
          ent:sensors{[name,"wellKnown_eci"]} := wellKnown_eci
          raise sensor event "make_subscription" attributes {
            "name":name,
            "wellKnown_eci":wellKnown_eci
          }
        }
    }

    rule make_subscription {
        select when sensor make_subscription
        event:send({"eci":event:attrs{"wellKnown_eci"},
          "domain":"wrangler", "name":"subscription",
          "attrs": {
            "wellKnown_Tx":ent:wellKnown_eci,
            "Rx_role":"manager", "Tx_role":"temperature_sensor",
            "name":event:attrs{"name"}+"-subscription", "channel_type":"subscription"
          }
        })
      }

    rule delete_sensor {
        select when sensor unneeded_sensor
        pre {
            name = event:attrs{"name"}
        }
        if ent:sensors >< name then noop()
        fired {
            raise wrangler event "subscription_cancellation"
                attributes {"Id": ent:sensors{[name, "wellKnown_eci"]}}
            raise wrangler event "child_deletion_request"
                attributes {"eci": ent:sensors{[name, "eci"]} };
            clear ent:sensors{name}
        }
    }
}