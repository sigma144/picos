ruleset manage_sensors {
    meta {
        name "Temperature Store"
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
        shares __testing, sensors, temps, testSubs, testReports, recentTemps
    }

    global {
        __testing = {
            "queries": [
                {"name": "sensors"},
                {"name": "temps"},
                {"name": "recentTemps"},
            ],
            "events": [
                {"domain": "sensor", "name": "new_sensor", "attrs":["name", "alert_number"]},
                {"domain": "sensor", "name": "unneeded_sensor", "attrs":["name"]},
                {"domain": "sensor", "name": "introduce_sensor", "attrs":["name", "eci"]},
                {"domain": "sensor", "name": "request_report", "attrs":[]},
                {"domain": "sensor", "name": "reset_reports", "attrs":[]},
                {"domain": "gossip", "name": "initialize", "attrs":[]},
                {"domain": "gossip", "name": "new_heartbeat_period", "attrs":["heartbeat_period"]},
            ]
        }
        github_path = "https://raw.githubusercontent.com/sigma144/picos/master/"
        //github_path = "file:///mnt/c/Users/Brian/Desktop/CS 462/picos/"
        sensors = function() {
            ent:sensors
        }
        testSubs = function() {
            temp_map = ent:sensors.map(function(eci,name) {
                subs:established("Id", eci{"subs_id"})
                    .filter(function(x){x{"Tx_role"} == "temperature_sensor"})
            })
            temp_map
        }
        temps = function() {
            temp_map = ent:sensors.map(function(eci,name) {
                peerSubs = subs:established("Id", eci{"subs_id"})
                    .filter(function(x){x{"Tx_role"} == "temperature_sensor"})
                sub = peerSubs.head()
                peerChannel = sub{"Tx"}
                peerHost = (sub{"Tx_host"} || meta:host)
                wrangler:skyQuery(peerChannel, "temperature_store","temperatures",{}, peerHost)
            })
            temp_map
        }
        recentTemps = function() {
            ent:recent_reports.length() > 5 => ent:recent_reports.slice(4) | ent:recent_reports
        }
        testReports = function() {
            ent:recent_reports
        }
        installRuleset = defaction(name, eci, rulesetURI) {
            event:send({
                "eci": eci,
                "eid": "install-ruleset-"+rulesetURI,
                "domain": "wrangler", "type": "install_ruleset_request",
                "attrs": {
                    "url": rulesetURI,
                    "name": name,
                    "wellKnown_eci":subs:wellKnown_Rx(){"id"}
                }
            })
        }
        threshold_default = 78
    }
    
    rule initialization {
        select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid
        always {
            ent:sensors := {}
            ent:temp_reports := {}
            ent:recent_reports := []
            ent:report_id := 0
            ent:heartbeat_period := 100
        }
    }

    rule initialize_children {
        select when gossip initialize
        foreach subs:established("Tx_role", "temperature_sensor") setting (sub)
        every {
            event:send({
                "eci":sub{"Tx"},
                "domain":"gossip",
                "type":"initialize",
            });
            event:send({
                "eci":sub{"Tx"},
                "domain":"sensor",
                "type":"reading_reset",
            });
        }
    }

    rule set_period_all {
        select when gossip new_heartbeat_period
        foreach subs:established("Tx_role", "temperature_sensor") setting (sub)
        event:send({
            "eci":sub{"Tx"},
            "domain":"gossip",
            "type":"new_heartbeat_period",
            "attrs":{"heartbeat_period":event:attrs{"heartbeat_period"}}
        });
    }

    rule new_sensor {
        select when sensor new_sensor
        pre {
            name = event:attrs{"name"}
            alert_number = event:attrs{"alert_number"}
        }
        if ent:sensors{name} then send_directive("Error", "A sensor with name '"+name+"' already exists.")
        notfired {
            raise wrangler event "new_child_request" attributes {
                "name": name,
                "alert_number": alert_number,
                "backgroundColor": "#ff69b4"
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
            raise wrangler event "subscription_cancellation"
                attributes {"Id": ent:sensors{[name, "subs_id"]} } if ent:sensors{[name, "subs_id"]}
            raise wrangler event "child_deletion_request"
                attributes {"eci": ent:sensors{[name, "eci"]} } if ent:sensors{[name, "eci"]};
            clear ent:sensors{name}
        }
    }

    rule install_sensor_profile {
        select when wrangler new_child_created
        installRuleset(event:attrs{"name"}, event:attrs{"eci"}, github_path+"Lab7/sensor_profile.krl")
    } 
    rule install_temperature_store {
        select when wrangler new_child_created
        installRuleset(event:attrs{"name"}, event:attrs{"eci"}, github_path+"Lab8/temperature_store.krl")
    }
    rule install_wovyn_base {
        select when wrangler new_child_created
        installRuleset(event:attrs{"name"}, event:attrs{"eci"}, github_path+"Lab7/wovyn_base.krl")
    }
    rule install_gossip_temps {
        select when wrangler new_child_created
        installRuleset(event:attrs{"name"}, event:attrs{"eci"}, github_path+"Lab9/gossip_temps.krl")
    }
    rule install_sensor_emulator {
        select when wrangler new_child_created
        installRuleset(event:attrs{"name"}, event:attrs{"eci"}, "https://raw.githubusercontent.com/windley/temperature-network/de63ef723bbdbf34b641dbc90835b70da7c2e407/io.picolabs.wovyn.emitter.krl")
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

    rule request_subsciption {
        select when wrangler new_child_created or sensor introduce_sensor
        event:send({"eci":event:attrs{"eci"},
            "domain":"wovyn", "name":"request_subscription",
            "attrs": {
                "manager_Rx":subs:wellKnown_Rx(){"id"},
                "Rx_role":"manager", "Tx_role":"temperature_sensor",
                "name":event:attrs{"name"}
            }
        })
    }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        if event:attrs{"Rx_role"}=="manager" && event:attrs{"Tx_role"}=="temperature_sensor" then noop()
        fired {
            raise wrangler event "pending_subscription_approval"
                attributes event:attrs
            ent:sensors{[event:attrs{"name"},"subs_eci"]} := event:attrs{"Tx"}
            ent:sensors{[event:attrs{"name"},"subs_id"]} := event:attrs{"Id"}
        } else {
        raise wrangler event "inbound_rejection"
            attributes event:attrs
        }
    }

    rule init_temperature_report {
        select when sensor request_report
        always {
            ent:temp_reports{ent:report_id} := {
                "temperature_sensors":subs:established().length(),
                "responding": 0,
                "temperatures": []
            }
        }
    }
    
    rule request_temperature_report {
        select when sensor request_report
        foreach subs:established("Tx_role", "temperature_sensor") setting (sub)
        event:send({
            "eci":sub{"Tx"},
            "eid":"request_report",                  
            "domain":"sensor",
            "type":"request_report",
            "attrs": {
                "report_id": ent:report_id,
                "Id": sub{"Id"}
            }
        })
        fired {
            ent:report_id := ent:report_id + 1 on final
        }
    }

    rule gather_report {
        select when sensor temperature_report
        pre {
            temps = [event:attrs{"report_id"}, "temperatures"]
            responding = [event:attrs{"report_id"}, "responding"]
        }
        always {
            ent:temp_reports{temps} := ent:temp_reports{temps}.append(event:attrs{"temp"})
            ent:temp_reports{responding} := ent:temp_reports{responding} + 1
        }
    }

    rule finalize_report {
        select when sensor temperature_report
        pre {
            sensors = [event:attrs{"report_id"}, "temperature_sensors"]
            responding = [event:attrs{"report_id"}, "responding"]
        }
        if ent:temp_reports{sensors} == ent:temp_reports{responding} then noop()
        fired {
            ent:recent_reports := ent:temp_reports{event:attrs{"report_id"}}.append(ent:recent_reports)
            clear ent:temp_reports{"report_id"}
        }
    }

    rule reset_reports {
        select when sensor reset_reports
        always {
            ent:temp_reports := {}
            ent:recent_reports := []
            ent:report_id := 0
        }
    }
}