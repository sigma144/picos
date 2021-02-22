ruleset sensor_profile {
    meta {
        name "Temperature Store"
        shares __testing, profile_info
        provides profile_info
    }
    global {
        __testing = { "queries": [
            {"name": "profile_info"}
        ], "events": [
            {"domain": "sensor", "name": "profile_updated", "args":["name", "location", "alert_number", "threshold"]},
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
