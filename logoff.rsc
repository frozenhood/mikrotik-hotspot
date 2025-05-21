:local userName $"user"
/log info ("[Logout Script] Starting cleanup check for user: " . $userName)

/ip hotspot user
:if ([find name=$userName] != "") do={

    :local userId [find name=$userName]
    :local limitUptime [get $userId limit-uptime]
    :local totalUptime [get $userId uptime]

    /log info ("[Logout Script] Found user. Uptime=" . $totalUptime . ", Limit=" . $limitUptime)

    :if ($limitUptime != "" && $totalUptime >= $limitUptime) do={

        /log info ("[Logout Script] Time expired for user " . $userName . ", performing cleanup...")

        # Remove user
        remove $userId
        /log info ("[Logout Script] User removed: " . $userName)

        # Remove IP binding
        /ip hotspot ip-binding
        :foreach binding in=[find mac-address=$userName] do={
            /log info ("[Logout Script] Removing IP binding for MAC: " . $userName)
            remove $binding

        # Disconnect Wi-Fi client from registration table
        :local wifiEntry [/interface wireless registration-table find mac-address=$userName]
        :if ([:len $wifiEntry] > 0) do={
              /interface wireless registration-table remove $wifiEntry
              :log info ("Hotspot Cleanup Script: Kicked Wi-Fi client " . $userName . " from wireless registration table.")
            } else {
                :log info ("Hotspot Cleanup Script: Wi-Fi client " . $userName . " not found in registration table.")
            }

        }

    } else={
        /log info ("[Logout Script] User " . $userName . " still has time remaining. No action taken.")
    }

} else={
    /log warning ("[Logout Script] User not found: " . $userName)
}