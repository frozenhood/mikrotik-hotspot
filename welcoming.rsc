:global telegramUserID
:global telegramBotToken
:local clientName $"user"
:local clientMac $"mac-address"

:local keyboard "{\"inline_keyboard\":[[{\"text\":\"1 hour\",\"callback_data\":\"allow_1h=$clientMac\"},{\"text\":\"3 hours\",\"callback_data\":\"allow_3h=$clientMac\"},{\"text\":\"24 hours\",\"callback_data\":\"allow_1d=$clientMac\"}], [{\"text\":\"1 week\",\"callback_data\":\"allow_1w=$clientMac\"},{\"text\":\"Permanently\",\"callback_data\":\"allow_perm=$clientMac\"},{\"text\":\"Deny\",\"callback_data\":\"deny=$clientMac\"}]]}"

:local messageText "New hotspot client:\nMAC: $clientMac\nChoose action:"

/tool fetch url=("https://api.telegram.org/bot" . $telegramBotToken . "/sendMessage") http-method=post http-data=("chat_id=" . $telegramUserID . "&text=" . $messageText . "&reply_markup=" . $keyboard) keep-result=no

:log info "Hotspot: Sent approval request to Telegram for Name: $clientName, MAC: $clientMac"