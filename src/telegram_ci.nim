import
  asyncdispatch, httpclient, logging, json, options, osproc, parsecfg,
  strformat, strutils, terminal, times, random, posix, os, posix_utils

import telebot, openexchangerates, openweathermap, zip/zipfiles

when not defined(linux): {.fatal: "Cannot run on Windows, try Docker for Windows: http://docs.docker.com/docker-for-windows".}
when not defined(ssl): {.fatal: "Cannot run without SSL, compile with -d:ssl".}
when defined(release): {.passL: "-s", passC: "-flto -ffast-math -march=native".}


const
  apiKey = staticRead("telegramkey.txt").strip
  oerApiKey = staticRead("openexchangerateskey.txt").strip
  owmApiKey = staticRead("openweathermapkey.txt").strip
  channelUserStr = staticRead("telegramchannel.txt").strip
  channelLink = staticRead("telegramchannellink.txt").strip
  oerCurrencies = "EUR,BGP,RUB,ARS,BRL,CNY,JPY,BTC,ETH,LTC,DOGE,XAU,UYU,PYG,BOB,CLP,CAD"
  pollingInterval = 1_000 * 1_000
  tempFolder = getTempDir()
  stripCmd = "strip --strip-all --remove-section=.comment"
  upxCmd = "upx --ultra-brute"
  shaCmd = "sha1sum --tag"
  gpgCmd = "gpg --clear-sign --armor"
  cutycaptCmd = "CutyCapt --insecure --smooth --private-browsing=on --plugins=on --header=DNT:1 --delay=9 --min-height=800 --min-width=1280 " ## Linux Bash command to take full Screenshots of Web pages from a link, we use Cutycapt http://cutycapt.sourceforge.net
  # cutycaptCmd = "xvfb-run --server-args='-screen 0, 1280x1024x24' CutyCapt --insecure --smooth --private-browsing=on --plugins=on --header=DNT:1 --delay=9 --min-height=800 --min-width=1280 "  ## Linux Bash command to take full Screenshots of Web pages from a link, we use Cutycapt http://cutycapt.sourceforge.net and XVFB for HeadLess Servers without X.
  ssdFree = """df --human-readable --local --total --print-type | awk '$1=="total"{print $5}'"""
  cpuFreeCmd = "mpstat -o JSON"
  nimbleRefreshCmd = "nimble refresh --accept --noColor"
  pipUpdateCmd = "pip install --quiet --exists-action w --upgrade --disable-pip-version-check pip virtualenv setuptools wheel pre-commit pre-commit-hooks prospector isort fades tox black pytest"
  choosenimUpdateCmd = "choosenim update self --yes --noColor ; choosenim update stable --yes --noColor"
  pythonVersion = staticExec("python3 --version").replace("Python", "").strip
  apiUrl = "https://api.telegram.org/file/bot$1/".format(apiKey)
  apiFile = "https://api.telegram.org/bot$1/getFile?file_id=".format(apiKey)
  gpuInfo = staticExec(
    "head -n 1 /proc/driver/nvidia/gpus/0000:01:00.0/information").replace(
    "Model:", "").strip
  ramSize = staticExec(
    "free --human --total --giga | awk '/^Mem:/{print $2}'").strip
  ssdSize = staticExec(
      """df --human-readable --local --total --print-type | awk '$1=="total"{print $3}'""").strip


let
  channelUser = channelUserStr.parseInt.int64
  oerClient = AsyncOER(timeout: 9, api_key: oerApiKey, base: "USD",
      local_base: "", round_float: true, prettyprint: false,
      show_alternative: true) ## OpenExchangeRates
  owmClient = AsyncOWM(timeout: 9, lang: "es", api_key: owmApiKey) ## OpenWeatherMap
  aboutText = fmt"""*Telegram CI: Continuos Build Service*
  *Description* = Builds 24/7, no VM, no hardware restrictions
  *CPU Count* = `{countProcessors()}`
  *RAM Size* = `{ramSize}`
  *SSD Size* = `{ssdSize}`
  *GPU Info* = `{gpuInfo}`
  *Uptime* = `{execCmdEx("uptime --pretty").output.strip}`
  *Linux* = `{uname().release}` 🐧
  *Arch* = `{hostCPU.toUpperAscii}` 💻
  *Nim* = `{NimVersion}` 👑
  *Python* = `{pythonVersion}` 🐍
  *Compiled* = `{CompileDate} {CompileTime}` ⏰
  *SSL* = `{defined(ssl)}` 🔐
  *Release* = `{defined(release)}`
  *Server Time* = `{$now()}`
  *Author* = _Juan Carlos_ @juancarlospaco
  *Powered by* = https://nim-lang.org
  *Bot* = `@nimlang_bot`
  *CI* = https://t.me/NimArgentinaCI
  *Group* = https://t.me/NimArgentina
  *Donate* = https://liberapay.com/juancarlospaco/donate
  *Build Count* = """

var counter: int ## Integer that counts how many times the bot has been used.


template handlerizer(body: untyped): untyped =
  ## This Template sends a markdown text message from the ``message`` variable.
  inc counter
  var send2user = true
  body
  var msg = newMessage(if send2user: update.message.chat.id else: channelUser,
    $message.strip()) #if send2user,sent to User via private,else send to public channel.
  msg.disableNotification = true
  msg.parseMode = "markdown"
  discard bot.send(msg)

template handlerizerPhoto(body: untyped): untyped =
  ## This Template sends a photo image message from the ``photo_path`` variable with the caption comment from ``photo_caption``.
  inc counter
  var send2user = true
  body
  var msg = newPhoto(if send2user: update.message.chat.id else: channelUser, photo_path)
  msg.caption = photo_caption
  msg.disableNotification = true
  discard bot.send(msg)

template handlerizerLocation(body: untyped): untyped =
  ## This Template sends a Geo Location message from the ``latitud`` and ``longitud`` variables.
  inc counter
  var send2user = true
  body
  let
    geo_uri = "*GEO URI:* geo:$1,$2    ".format(latitud, longitud)
    osm_url = "*OSM URL:* https://www.openstreetmap.org/?mlat=$1&mlon=$2".format(
        latitud, longitud)
  var
    msg = newMessage(if send2user: update.message.chat.id else: channelUser, geo_uri & osm_url)
    geo_msg = newLocation(if send2user: update.message.chat.id else: channelUser, longitud, latitud)
  msg.disableNotification = true
  geo_msg.disableNotification = true
  msg.parseMode = "markdown"
  discard bot.send(geo_msg)
  discard bot.send(msg)

template handlerizerDocument(body: untyped): untyped =
  ## This Template sends an attached File Document message from the ``document_file_path`` variable with the caption comment from ``document_caption``.
  inc counter
  var send2user = true
  body
  var document = newDocument(if send2user: update.message.chat.id else: channelUser,
    "file://" & document_file_path)
  document.caption = document_caption.strip
  document.disableNotification = true
  discard bot.send(document)


proc aboutHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    let message = aboutText & $counter

proc donateHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    let message = "https://liberapay.com/juancarlospaco/donate"

proc staticHandler(static_file: string): CommandCallback =
  proc cb(bot: Telebot, update: Command) {.async.} =
    handlerizerDocument():
      let
        document_file_path = static_file
        document_caption = static_file
  return cb

proc lshwHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    var send2user = false
    let message = fmt"""`{execCmdEx("lshw -short")[0]}`"""

proc nimbleRefreshHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    var send2user = false
    let message = fmt"""`{execCmdEx(nimbleRefreshCmd)[0]}`"""

proc choosenimHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    var send2user = false
    let message = fmt"""`{execCmdEx(choosenimUpdateCmd)[0]}`"""

proc pipUpdateHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    var send2user = false
    let message = fmt"""`{execCmdEx(pipUpdateCmd)[0]}`"""

proc dfHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    var send2user = false
    let message = fmt"""**SSD Free Space** `{execCmdEx(ssdFree)[0]}`"""

proc freeHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    var send2user = false
    let message = fmt"""`{execCmdEx("free --human --total --giga")[0]}`"""

proc channelHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    let message = channelLink

proc cpuHandler(bot: Telebot, update: Command) {.async.} =
  let cpu = parseJson(execCmdEx(cpuFreeCmd)[0]
    )["sysstat"]["hosts"][0]["statistics"][0]["cpu-load"][0]
  handlerizer():
    let message = fmt"""**Total stats of all CPUs**
    **Idle** `{cpu["idle"]}`%
    **System** `{cpu["sys"]}`%
    **User** `{cpu["usr"]}`%
    **Waiting for I/O** `{cpu["iowait"]}`%
    **Interrupt Request IRQ** `{cpu["irq"]}`%
    **Guests** `{cpu["guest"]}`%
    **Steal** `{cpu["steal"]}`%
    **Soft** `{cpu["soft"]}`%
    **Nice** `{cpu["nice"]}`%
    **General Nice** `{cpu["gnice"]}`%"""

proc dollarHandler(bot: Telebot, update: Command) {.async.} =
  let
    money_json = waitFor oerClient.latest() # Updated Prices.
    nms = waitFor oerClient.currencies() # Friendly Names.
  var dineros = "*Dollar USD* 💲🇺🇸\n"
  for crrncy in money_json.pairs:
    if crrncy[0] in oerCurrencies:
      dineros.add(fmt"*{crrncy[0]}* _{nms[crrncy[0]]}_ `{crrncy[1]}`" & "\n")
  handlerizer():
    let message = dineros

proc weatherHandler(bot: Telebot, update: Command) {.async.} =
  let
    wea = waitFor owmClient.get_current_cityname(city_name = "buenos aires",
        country_code = "AR", accurate = true)
    uvs = waitFor owmClient.get_uv_current_coordinates(
      lat = -34.61, lon = -58.44)
    t0 = format(fromUnix(wea["sys"]["sunrise"].getInt.int64), "HH:mm")
    t1 = format(fromUnix(wea["sys"]["sunset"].getInt.int64), "HH:mm")
    dt = format(fromUnix(wea["dt"].getInt.int64), "HH:mm")
    tz = format(fromUnix(wea["timezone"].getInt.int64), "zzz")
    msg = fmt"""*{wea["name"].str}, {wea["sys"]["country"].str}* 🇦🇷
    *Temperatura* `{wea["main"]["temp"]}` Celsius
    *Temperatura Min* `{wea["main"]["temp_min"]}` Celsius
    *Temperatura Max* `{wea["main"]["temp_max"]}` Celsius
    *Humedad* `{wea["main"]["humidity"]}`%
    *Viento* `{wea["wind"]["speed"]}` Metros/Segundo
    *Visibilidad* `{wea["visibility"]}` Metros
    *Nubosidad* `{wea["clouds"]["all"]}`%
    *Presion* `{wea["main"]["pressure"]}`
    *Sale el Sol* `{ t0 }` Horas
    *Oculta el Sol* `{ t1 }` Horas
    *Rayos Ultravioleta UV* `{ uvs["value"] }`
    *Latitud* `{wea["coord"]["lat"]}` Grados
    *Longitud* `{wea["coord"]["lon"]}` Grados
    *Zona Horaria* `{ tz }` UTC
    *Ultima Medicion* `{ dt }` Horas
    *Pronostico* `{ wea["weather"][0]["main"].str }, { wea["weather"][0]["description"].str }`"""
  handlerizer():
    let message = msg

proc rmTmpHandler(bot: Telebot, update: Command) {.async.} =
  var msg = "*Deleted Files*\n"
  for file in walkFiles(tempFolder / "**/*.*"):
    msg.add file & "\n"
    removeFile(file)
  handlerizer():
    let message = msg

proc echoHandler(bot: Telebot, update: Command) {.async.} =
  let echoData = fmt"""*Echo*
  *Your Username* `{ update.message.chat.username }`
  *Your First Name* `{ update.message.chat.first_name }`
  *Your Last Name* `{ update.message.chat.last_name }`
  *Your User ID* `{ update.message.chat.id }`
  *Your Chat Date* `{ update.message.date }`
  *Message ID* `{ update.message.messageId }`
  *Message Text* `{ update.message.text }`
  _This is all information about you that a Bot can see._"""
  var msg = newMessage(update.message.chat.id, echoData)
  msg.disableNotification = true
  msg.parseMode = "markdown"
  discard bot.send(msg)


proc main() {.async.} =
  addHandler(newConsoleLogger(fmtStr = verboseFmtStr))
  addHandler(newRollingFileLogger())
  let bot = newTeleBot(apiKey)
  bot.onCommand("about", aboutHandler)
  bot.onCommand("help", aboutHandler)
  bot.onCommand("ayuda", aboutHandler)
  bot.onCommand("donate", donateHandler)
  bot.onCommand("donar", donateHandler)
  bot.onCommand("lshw", lshwHandler)
  bot.onCommand("df", dfHandler)
  bot.onCommand("free", freeHandler)
  bot.onCommand("cpu", cpuHandler)
  bot.onCommand("dollar", dollarHandler)
  bot.onCommand("dolar", dollarHandler)
  bot.onCommand("clima", weatherHandler)
  bot.onCommand("weather", weatherHandler)
  bot.onCommand("nimblerefresh", nimbleRefreshHandler)
  bot.onCommand("choosenimupdate", choosenimHandler)
  bot.onCommand("pipupdate", pipUpdateHandler)
  bot.onCommand("rmtmp", rmTmpHandler)
  bot.onCommand("echo", echoHandler)
  bot.onCommand("channel", channelHandler)
  bot.onCommand("link", channelHandler)
  #bot.onUpdate(handleUpdate)
  discard nice(19.cint)       # smooth cpu priority
  bot.poll(pollingInterval)


when isMainModule:
  waitFor main()
