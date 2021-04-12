ruleset gossip_temps {
    meta {
        name "Temperature Gossip"
        shares __testing, getRumors, getSeen, getSeenRecord, getViolationTotal
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
        use module sensor_profile alias profile
    }
    global {
        __testing = { "queries": [
            {"name": "getRumors"},
            {"name": "getSeen"},
            {"name": "getSeenRecord"},
            {"name": "getViolationTotal"},
        ], "events": [
            {"domain": "gossip", "name": "add_peer", "attrs":["eci"]},
            {"domain": "gossip", "name": "remove_peer", "attrs":["eci"]},
            {"domain": "gossip", "name": "heartbeat"},
            {"domain": "gossip", "name": "new_heartbeat_period", "attrs":["heartbeat_period"]},
            {"domain": "gossip", "name": "process", "attrs":["state"]},
        ] }
        getRumors = function() {
            ent:rumors
        }
        getSeen = function() {
            ent:seen
        }
        getViolationTotal = function() {
            ent:violation_total
        }
        getSeenNumber = function(id) {
            nums = ent:rumors{id}.values().map(function(v) {v{"Message#"}})
            max = nums.reduce(function(x,n) {n > x => n | x}, 0).klog("Max")
            0.range(max).reduce(function(x,n) {
                n == x+1 && nums >< n => n | x
            }, 0)
        }
        getSeenRecord = function() {
            ent:rumors.map(function(v,k) {getSeenNumber(k)})
        }
        getNeededRumors = function(seen) {
            ent:rumors.map(function(v,k) {seen >< k =>
                v.filter(function(msg) { msg{"Message#"}.as("Number") > seen{k} })
            | v })
        }
        createRumor = function(temp, timestamp) {
            {
                "MessageID": ent:id + ":" + ent:message_num,
                "SensorID": ent:id,
                "Message#": ent:message_num,
                "Temperature": temp,
                "Timestamp": timestamp,
            }
        }
        createViolation = function(violation, timestamp) {
            {
                "MessageID": ent:id + ":" + ent:message_num,
                "SensorID": ent:id,
                "Message#": ent:message_num,
                "Violation": violation,
                "Timestamp": timestamp,
            }
        }
        sendRumorMessage = defaction() {
            needed = ent:peers.map(function(v,k) { getNeededRumors(ent:seen >< k => ent:seen{k} | {}) })
                    .filter(function(v,k) { v.length() > 0 }).klog("Needed")
            id = needed.keys()[random:integer(needed.length() - 1)]
            if id then event:send({
                "eci":ent:peers{id},
                "domain":"gossip",
                "type":"rumor",
                "attrs": needed{id}
            });
        }
        sendSeenMessage = defaction() {
            record = getSeenRecord()
            needed = ent:peers.map(function(v,k) { ent:seen{k} })
                .filter(function(v,k) { v != record })
            id = needed.keys()[random:integer(needed.length() - 1)]
            if id then event:send({
                "eci":ent:peers{id},
                "domain":"gossip",
                "type":"seen",
                "attrs": {"from":ent:id, "seen":record}
            });
        }
    }
    rule initialization {
        select when wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid
        always {
            ent:id := wrangler:name() + "." + random:uuid()
            ent:peers := {}
            ent:gossip_state := "on"
            ent:gossip_period := 15
            schedule gossip event "heartbeat" repeat << */#{ent:gossip_period} * * * * * >>  attributes { }
        }
    }
    rule reset_gossip {
        select when gossip initialize or wrangler ruleset_installed where event:attrs{"rids"} >< meta:rid
        always {
            ent:rumors := {}
            ent:seen := {}
            ent:message_num := 1
            ent:violation_status := 0
            ent:violation_total := 0
        }
    }
    rule collect_temperatures {
        select when wovyn new_temperature_reading
        pre {
            temperature = event:attrs{"temperature"}{"temperatureF"}
            threshold = profile:profile_info(){"threshold"}
            time = event:attrs{"timestamp"}
            violation = temperature > threshold => 1 | 0
            change = violation - ent:violation_status
        }
        always{
            ent:rumors{[ent:id, "#"+ent:message_num]} := createRumor(temperature, time)
            ent:message_num := ent:message_num + 1
            ent:rumors{[ent:id, "#"+ent:message_num]} := createViolation(change, time) if change
            ent:message_num := ent:message_num + 1 if change
            ent:violation_status := violation
            ent:violation_total := ent:violation_total + change
        }
    }
    rule set_heartbeat_operation {
        select when gossip process
        always {
            ent:gossip_state := event:attrs{"state"};
        }
    }
    rule set_period {
        select when gossip new_heartbeat_period
        schedule:remove(schedule:list()[0]{"id"})
        always {
            ent:gossip_period := event:attrs{"heartbeat_period"}
            schedule gossip event "heartbeat" repeat << */#{ent:gossip_period} * * * * * >>  attributes { }
        }
    }
    rule gossip_heartbeat {
        select when gossip heartbeat
        pre {
            peers = subs:established("Tx_role", "node")
            sub = peers[random:integer(peers.length() - 1)]
        }
        if ent:gossip_state == "on" then sample {
            sendRumorMessage();
            sendSeenMessage();
        }
    }

    rule store_rumors {
        select when gossip rumor
        foreach event:attrs setting (rumors, id)
        foreach rumors setting (msg, msg_num)
        always {
            ent:violation_total := ent:violation_total + msg{"Violation"}
                if ent:gossip_state == "on" && msg{"Violation"} && not ent:rumors{[id, msg_num]}
            ent:rumors{[id, msg_num]} := msg if ent:gossip_state == "on"
            
        }
    }
    rule store_seen {
        select when gossip seen
        always {
            ent:seen{event:attrs{"from"}} := event:attrs{"seen"} if ent:gossip_state == "on"
        }
    }
    rule respond_seen {
        select when gossip seen
        pre {
            needed = getNeededRumors(event:attrs{"seen"})
        }
        if needed.length() > 0 then event:send({
            "eci":ent:peers{event:attrs{"from"}},
            "domain":"gossip",
            "type":"rumor",
            "attrs": needed
        })
    }

    //Subscription stuff

    rule request_subscription {
        select when gossip add_peer
        event:send({"eci":event:attrs{"eci"},
            "domain":"gossip", "name":"request_subscription",
            "attrs": {
                "peer_Rx":subs:wellKnown_Rx(){"id"},
                "Rx_role":"node", "Tx_role":"node"
            }
        })
        fired {
            raise wrangler event "pending_subscription_approval" attributes event:attrs
        } 
    }
    rule create_subscription {
        select when gossip request_subscription
        always {
            raise wrangler event "subscription" attributes {
                "wellKnown_Tx":event:attrs{"peer_Rx"},
                "Rx_role":event:attrs{"Tx_role"}, "Tx_role":event:attrs{"Rx_role"},
                "SensorID":ent:id, "channel_type":"subscription"
            }
        }
    }
    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        if event:attrs{"Rx_role"}=="node" && event:attrs{"Tx_role"}=="node" then //noop()
            event:send({"eci":event:attrs{"Tx"},
                "domain":"gossip", "name":"subscription_accepted",
                "attrs": {
                    "peer_Rx":event:attrs{"Rx"},
                    "SensorID":ent:id
                }
            })
        fired {
            raise wrangler event "pending_subscription_approval" attributes event:attrs
            ent:peers{event:attrs{"SensorID"}} := event:attrs{"Tx"}
        } else {
        raise wrangler event "inbound_rejection"
            attributes event:attrs
        }
    }
    rule subscription_accepted {
        select when gossip subscription_accepted
        always {
            ent:peers{event:attrs{"SensorID"}} := event:attrs{"peer_Rx"}
        }
    }
    rule delete_subscription {
        select when gossip remove_peer
        event:send({"eci":event:attrs{"eci"},
            "domain":"gossip", "name":"clear_subscription_record",
            "attrs": { "eci": subs:wellKnown_Rx(){"id"} }
        })
        fired {
            raise wrangler event "subscription_cancellation"
                attributes {"Tx": event:attrs{"eci"}}
        }
    }
    rule clear_subscription_record {
        select when gossip remove_peer
        always {
            ent:peers := ent:peers.filter(function(v,k) { v != event:attrs{"eci"} })
        }
    }
}