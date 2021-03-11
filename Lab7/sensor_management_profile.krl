ruleset sensor_management_profile {
    meta {
        name "Temperature Store"
        shares __testing, profile_info
        provides profile_info
        use module twilio_api alias twilio
        with
            sid = meta:rulesetConfig{"sid"}
            authToken = meta:rulesetConfig{"auth_token"}
            from_number = meta:rulesetConfig{"phone_number"}
    }
    global {
        __testing = {
            "queries": [
                {"name": "profile_info"}
            ],
            "events": [
                {"domain": "sensor", "name": "profile_updated",
                "attrs":["alert_number", "threshold"]},
                {"domain": "sensor", "name": "profile_updated"}
            ]
        }
        profile_info = function(obj) {
            {
                "alert_number":ent:profile_alert_number.defaultsTo(""),
            }
        }
    }

    rule update_profile {
        select when sensor profile_updated
        pre {
            threshold = event:attrs{"threshold"}
            alert_number = event:attrs{"alert_number"}
          }
          send_directive("Update Profile", {
            "alert_number":alert_number,
            "threshold":threshold
          })
          always {
            ent:profile_alert_number := alert_number
            ent:profile_threshold := threshold
          }
    }

    
    rule threshold_notification {
        select when sensor threshold_violation
        twilio:sendTextMessage(ent:profile_alert_number, event:attrs{"message"})
    }
}
