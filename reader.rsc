:global telegramUserID
:global telegramBotToken
:global userPass
:global telegramOffset


# Define a function to send Telegram API requests
:global sendTelegramApiRequest do={
    :local url $1;
    :local method $2;
    :local data $3;

    :log debug ("Sending Telegram API request to " . $url . " with method " . $method);
    :if ([:len $data] > 0) do={
        :log debug ("Data: " . $data);
    }

    /tool fetch url=($url) http-method=$method http-data=$data keep-result=no
}

# --- Main script starts here ---

:local url ("https://api.telegram.org/bot" . $telegramBotToken . "/getUpdates?offset=" . $telegramOffset)
:local result [/tool fetch url=$url http-method=get as-value output=user]
:local rawdata ($result->"data")

# Clean rawdata from newlines to make JSON parsing easier
:local cleanData ""
:for i from=0 to=([:len $rawdata] - 1) do={
    :local char [:pick $rawdata $i]
    :if ($char != "\n") do={
        :set cleanData ($cleanData . $char)
    }
}

:local jsonData [:deserialize from=json $cleanData]

:local updates ($jsonData->"result")
:local lastUpdateId $telegramOffset

:if ([:len $updates] > 0) do={
    :log info ("Hotspot: Received Telegram update.")

    :local updateItem ($updates->0)
    :if ([:typeof ($updateItem->"callback_query")] != "nil") do={

        :local cbQuery ($updateItem->"callback_query")
        :local cbData ($cbQuery->"data")
        :local queryId ($cbQuery->"id")
        :local messageId ($cbQuery->"message"->"message_id")
        :local chatId ($cbQuery->"message"->"chat"->"id")

        :local action ""
        :local clientMac ""

        :local eqPos [:find $cbData "="]
        :if ($eqPos != -1) do={
            :set action [:pick $cbData 0 $eqPos]
            :set clientMac [:pick $cbData ($eqPos + 1) [:len $cbData]]
        } else={
            :log warning ("Hotspot: Invalid callback data format: " . $cbData)
            :return
        }

        :local hotspotProfile ""

        :if ($action = "allow_1h") do={
            :set hotspotProfile "1h"
        }
        :if ($action = "allow_3h") do={
            :set hotspotProfile "3h"
        }
        :if ($action = "allow_1d") do={
            :set hotspotProfile "1d"
        }
        :if ($action = "allow_1w") do={
            :set hotspotProfile "1w"
        }
        :if ($action = "allow_perm") do={
            :set hotspotProfile "perm"
        }
        :if ($action = "deny") do={
            /ip hotspot ip-binding
            :if ([:len [find where mac-address=$clientMac]] = 0) do={
                add mac-address=$clientMac type=blocked
                :log info ("Hotspot: IP binding blocked for " . $clientMac)
            }
        }

        :if ([:len $hotspotProfile] > 0 && [:len $clientMac] > 0) do={

            # Check if user already exists — skip if so
            /ip hotspot user
            :if ([:len [find where name=$clientMac]] = 0) do={

                :log info ("Hotspot: Adding user " . $clientMac . " with profile " . $hotspotProfile)
                add name=$clientMac password=$userPass profile=$hotspotProfile
                
                /ip hotspot ip-binding
                :if ([:len [find where mac-address=$clientMac]] = 0) do={
                    add mac-address=$clientMac type=bypassed
                    :log info ("Hotspot: IP binding added for " . $clientMac)
                }

                /ip hotspot active
                :local hsAct [/ip hotspot active find mac-address=$clientMac]
                :if ([:len $hsAct] > 0) do={
                    remove $hsAct
                    :log info ("Hotspot: Removed active session for " . $clientMac)
                }

                /ip hotspot ip-binding
                :local bindingId [find where mac-address=$clientMac]
                :if ([:len $bindingId] != 0) do={
                    set $bindingId type=regular
                   :log info ("Hotspot: IP binding updated to regular for " . $clientMac)
                }

            } else={
                :log info ("Hotspot: User already exists, skipping creation: " . $clientMac)
            }
            :local sessionTimeout [/ip hotspot user profile get $hotspotProfile session-timeout]
            /ip hotspot user set [find where name=$clientMac] limit-uptime=$sessionTimeout
        }

        # Answer callback query
        :local answerUrl ("https://api.telegram.org/bot" . $telegramBotToken . "/answerCallbackQuery")
        :local answerData ("callback_query_id=" . $queryId)
        :do { $sendTelegramApiRequest $answerUrl "post" $answerData } on-error={ :log error "Hotspot: Failed to answer callback query." }

        # Remove inline buttons
        :local editUrl ("https://api.telegram.org/bot" . $telegramBotToken . "/editMessageReplyMarkup")
        :local editData ("chat_id=" . $chatId . "&message_id=" . $messageId . "&reply_markup={}")
        :do { $sendTelegramApiRequest $editUrl "post" $editData } on-error={ :log error "Hotspot: Failed to edit reply markup." }

    } else={
        :log info ("Hotspot: Skipping non-callback update.")
    }

    :set telegramOffset (($updateItem->"update_id") + 1)
} else={
    :log info "Hotspot: No new Telegram updates."
}