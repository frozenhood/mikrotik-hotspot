# Hotspot Telegram Approval System

## Описание

Данный набор скриптов реализует систему авторизации клиентов Mikrotik Hotspot через Telegram-бота.  
Администратор может одобрять или отклонять доступ новых клиентов, а также выбирать срок действия доступа (1 час, 3 часа, 1 день, 1 неделя, постоянно).

---

## Структура файлов

| Файл           | Назначение                                                                                   |
|----------------|---------------------------------------------------------------------------------------------|
| `onstart.rsc`  | Инициализация глобальных переменных (токен, chat ID, пароль, offset)                        |
| `welcoming.rsc`| Отправка запроса в Telegram-бот с кнопками для выбора времени доступа                       |
| `reader.rsc`   | Опрашивает Telegram-бота, обрабатывает решения, создает пользователей, управляет сессиями    |
| `logoff.rsc`   | Очистка после завершения сессии: удаление пользователя, IP binding, отключение от Wi-Fi      |

---

## Переменные и их настройка

Перед использованием необходимо задать значения переменных в `onstart.rsc`:

```rsc
:global telegramBotToken "Your valid telegram bot token"   # Telegram bot token
:global telegramUserID "Chat ID"                           # Admin chat ID (get via @userinfobot)
:global userPass "Pass for MAC users"                      # Password for MAC users
:global telegramOffset 0                                   # Offset for Telegram API (leave 0)
```

---

## Схема работы

1. **Клиент подключается к Hotspot**  
   Авторизация через фиксированный логин/пароль (например, trial/trial вшитый в форму).

2. **`welcoming.rsc`**  
   При входе клиента отправляет запрос в Telegram-бот с кнопками для выбора времени доступа.

3. **Администратор выбирает действие**  
   В Telegram-боте администратор выбирает срок доступа или отклоняет клиента.

4. **`reader.rsc`**  
   Периодически (каждые 15 секунд) опрашивает Telegram-бота, получает решения, создает пользователя с нужным профилем, сбрасывает временную сессию, настраивает IP binding.

5. **Клиент повторно авторизуется**  
   Теперь он может войти с новым логином (MAC-адрес) и общим паролем.

6. **`logoff.rsc`**  
   При завершении сессии пользователя и исчерпании лимита скрипт выполняет очистку: удаляет пользователя, IP binding, отключает от Wi-Fi.

---

## Установка

### 1. Инициализация переменных при старте

**Создайте скрипт `onstart` с содержимым:**

из файла onstart.rsc

**Добавьте задачу в планировщик для автозапуска скрипта при старте системы:**

```rsc
/system scheduler
add name="init-hotspot-vars" on-event="/system script run onstart" start-time=startup run-at-startup=yes
```

### 2. Настройка сети и Hotspot

```rsc
/interface vlan add name=vlan50-hotspot vlan-id=50 interface=bridge1
/ip address add address=192.168.50.1/24 interface=vlan50-hotspot
/ip pool add name=hs-pool ranges=192.168.50.10-192.168.50.100
/ip dhcp-server add name=hs-dhcp interface=vlan50-hotspot address-pool=hs-pool disabled=no
/ip dhcp-server network add address=192.168.50.0/24 gateway=192.168.50.1 dns-server=1.1.1.1
/ip dns set servers=1.1.1.1 allow-remote-requests=yes
/ip hotspot setup interface=vlan50-hotspot address-pool=hs-pool dns-name=hotspot.local \
    gateway-address=192.168.50.1 dns-server=1.1.1.1
```

### 3. Настройка профилей и пользователей

```rsc
/ip hotspot profile
add name=hsprof hotspot-address=192.168.50.1 \
    dns-name=hotspot.local html-directory=hotspot \
    login-by=mac,http-chap,http-pap use-radius=no mac-auth-password=$userPass

/ip hotspot user
add name=trial password=trial profile=welcoming

/ip hotspot user profile
add name=1h session-timeout=1h on-logout=logoff shared-users=1
add name=3h session-timeout=3h on-logout=logoff shared-users=1
add name=1d session-timeout=1d on-logout=logoff shared-users=1
add name=1w session-timeout=1w on-logout=logoff shared-users=1
add name=perm shared-users=1
add name=deny session-timeout=1m
add name=welcoming on-login=welcoming session-timeout=10m address-list=deny_internet_list shared-users=10

/ip firewall filter
add chain=forward action=drop comment="Block all internet for deny_internet profile" \
    src-address-list=deny_internet_list
```

### 4. Запуск основного скрипта-обработчика

**Создайте скрипт `reader` с содержимым:**

из файла reader.rsc

**Добавьте задачу в планировщик для запуска скрипта по интервалу:**

```rsc
/system scheduler add name="run-reader" interval=15s on-event="/system script run reader" start-time=startup
```

### 5. Добавление остальных скриптов-обработчиков

**Создайте скрипт `welcoming` с содержимым:**

из файла welcoming.rsc

**Создайте скрипт `logoff` с содержимым:**

из файла logoff.rsc

### 6. Копирование кастомизированных html файлов

**Скопируйте на роутер файл `login.html` с формой входа:**

**Скопируйте на роутер файл `alogin.html` с формой тестирования наличия интернет:**

---

## Рекомендации по безопасности

- Используйте сложный общий пароль для MAC-пользователей.
- Не публикуйте токен Telegram-бота и chat ID в открытом доступе.
- Ограничьте доступ к скриптам только доверенным администраторам.

---

## FAQ

<details>
<summary><strong>Telegram-бот не отвечает на запросы</strong></summary>
Проверьте токен и chat ID, убедитесь, что бот запущен и доступен из вашей сети.
</details>

<details>
<summary><strong>Пользователь не создаётся после одобрения</strong></summary>
Проверьте логи на роутере, убедитесь, что reader.rsc выполняется по расписанию.
</details>

<details>
<summary><strong>Как узнать chat ID?</strong></summary>
Напишите любому боту @userinfobot в Telegram.
</details>

---

## Контакты

Для вопросов и предложений: Telegram: @r0abz
