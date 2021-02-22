ruleset sensor_profile {
    meta {
        name "Temperature Store"
        shares __testing, temperatures, threshold_violations, inrange_temperatures
        provides temperatures, threshold_violations, inrange_temperatures
    }
    global {
        __testing = { "queries": [
            {"name": "temperatures"},
            {"name": "threshold_violations"},
            {"name": "inrange_temperatures"}
        ], "events": [
            {"domain": "sensor", "name": "reading_reset"},
        ] }
        profile_info = function(obj) {
            {
                "name":ent:profile_name.defaultsTo(""),
                "location":ent:profile_location.defaultsTo(""),
                "alert_number":ent:profile_alert_number(""),
                "threshold":ent:profile_threshold.defaultsTo(80)
            }
        }
    }

    rule update_profile {
        select when sensor profile_updated
        pre {
            name = event:attrs{"name"}
            location = event:attrs{"location"}
            threshold = event:attrs{"threshold"}
            alert_number = event:attrs{"alert_number"}
          }
          send_directive("Update Profile", {
            "name":ent:profile_name,
            "location":ent:profile_location,
            "alert_number":ent:profile_alert_number,
            "threshold":ent:profile_threshold
          })
          always {
            ent:profile_name := name
            ent:profile_location := location
            ent:profile_alert_number := alert_number
            ent:profile_threshold := threshold
          }
    }
}
