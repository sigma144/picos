ruleset temperature_store {
    meta {
        name "Temperature Store"
        shares __testing, temperatures, threshold_violations, inrange_temperatures
        provides temperatures, threshold_violations, inrange_temperatures
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subs
    }
    global {
        __testing = { "queries": [
            {"name": "temperatures"},
            {"name": "threshold_violations"},
            {"name": "inrange_temperatures"}
        ], "events": [
            {"domain": "sensor", "name": "reading_reset"},
        ] }
        temperatures = function(obj) { ent:temps.defaultsTo({}) }
        threshold_violations = function(obj) { ent:violations.defaultsTo({}) }
        inrange_temperatures = function(obj) {
            ent:temps.filter(function(v,k){ent:violations{k} == null})
        }
    }

    rule collect_temperatures {
        select when wovyn new_temperature_reading
        pre {
            temperature = event:attrs{"temperature"}{"temperatureF"}
            time = event:attrs{"timestamp"}
        }
        always{
            ent:temps := ent:temps.defaultsTo({});
            ent:temps{time} := temperature
        }
    }

    rule collect_threshold_violations {
        select when wovyn threshold_violation
        pre {
            temperature = event:attrs{"temperature"}
            time = event:attrs{"timestamp"}
        }
        always{
            ent:violations := ent:violations.defaultsTo({});
            ent:violations{time} := temperature
        }
    }

    rule clear_temperatures {
        select when sensor reading_reset
        always{
            ent:temps := {}
            ent:violations := {}
        }
    }
    
    rule report_temps {
        select when sensor request_report
        foreach subs:established("Id", event:attrs{"Id"}) setting (sub)
        event:send({
            "eci":sub{"Tx"},
            "eid":"temp_report",
            "domain":"sensor",
            "type":"temperature_report",
            "attrs": {
              "temp": ent:temps{ent:temps.keys()[ent:temps.length() - 1]},
              "report_id": event:attrs{"report_id"}
            }
        })
    }
}
