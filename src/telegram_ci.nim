import
  asyncdispatch, httpclient, logging, json, options, osproc, parsecfg,
  strformat, strutils, terminal, times, random, posix, os, posix_utils

import telebot, openexchangerates, openweathermap, zip/zipfiles

when not defined(linux): {.fatal: "Cannot run on Windows, try Docker for Windows: http://docs.docker.com/docker-for-windows".}
# when not defined(ssl): {.fatal: "Cannot run without SSL, compile with -d:ssl".}
when defined(release): {.passL: "-s", passC: "-flto -ffast-math -march=native".}

include "constants.nim"
include "variables.nim"

var counter: int ## Integer that counts how many times the bot has been used.


template handlerizer(body: untyped): untyped =
  ## This Template sends a markdown text message from the ``message`` variable.
  inc counter
  body
  var msg = newMessage(if declared(send2channel): channelUser else: update.message.chat.id,
    $message.strip()) #if send2user,sent to User via private,else send to public channel.
  msg.disableNotification = true
  msg.parseMode = "markdown"
  discard bot.send(msg)

template handlerizerPhoto(body: untyped): untyped =
  ## This Template sends a photo image message from the ``photo_path`` variable with the caption comment from ``photo_caption``.
  inc counter
  body
  var msg = newPhoto(if declared(send2channel): channelUser else: update.message.chat.id, photo_path)
  msg.caption = photo_caption
  msg.disableNotification = true
  discard bot.send(msg)

template handlerizerLocation(body: untyped): untyped =
  ## This Template sends a Geo Location message from the ``latitud`` and ``longitud`` variables.
  inc counter
  body
  let
    geo_uri = "*GEO URI:* geo:$1,$2    ".format(latitud, longitud)
    osm_url = "*OSM URL:* https://www.openstreetmap.org/?mlat=$1&mlon=$2".format(
        latitud, longitud)
  var
    msg = newMessage(if declared(send2channel): channelUser else: update.message.chat.id, geo_uri & osm_url)
    geo_msg = newLocation(if declared(send2channel): channelUser else: update.message.chat.id, longitud, latitud)
  msg.disableNotification = true
  geo_msg.disableNotification = true
  msg.parseMode = "markdown"
  discard bot.send(geo_msg)
  discard bot.send(msg)

template handlerizerDocument(body: untyped): untyped =
  ## This Template sends an attached File Document message from the ``document_file_path`` variable with the caption comment from ``document_caption``.
  inc counter
  body
  var document = newDocument(
    if declared(send2channel): channelUser else: update.message.chat.id,
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
    let send2channel = true
    let message = fmt"""`{execCmdEx("lshw -short")[0]}`"""

proc nimbleRefreshHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    let send2channel = true
    let message = fmt"""`{execCmdEx(nimbleRefreshCmd)[0]}`"""

proc choosenimHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    let send2channel = true
    let message = fmt"""`{execCmdEx(choosenimUpdateCmd)[0]}`"""

proc pipUpdateHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    let send2channel = true
    let message = fmt"""`{execCmdEx(pipUpdateCmd)[0]}`"""

proc dfHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    let send2channel = true
    let message = fmt"""**SSD Free Space** `{execCmdEx(ssdFree)[0]}`"""

proc freeHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    let send2channel = true
    let message = fmt"""`{execCmdEx("free --human --total --giga")[0]}`"""

proc uptimeHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    let send2channel = true
    let message = fmt"""`{execCmdEx("uptime --pretty")[0]}`"""

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
    let send2channel = true
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

proc urlHandler(bot: Telebot, update: Command) {.async.} =
  let url = update.message.text.get.replace("/url", "").strip.quoteShell
  if url.startsWith("http://") or url.startsWith("https://") and url.len < 1_000:
    let (output0, exitCode0) = execCmdEx(cutycaptCmd & "--out=" & cutycaptPdf & " --url=" & url)
    if exitCode0 == 0:
      handlerizerDocument():
        let document_file_path = cutycaptPdf
        let document_caption = url
    let (output1, exitCode1) = execCmdEx(cutycaptCmd & "--out=" & cutycaptJpg & " --url=" & url)
    if exitCode1 == 0:
      handlerizerDocument():
        let document_file_path = cutycaptJpg
        let document_caption = url

proc geoHandler(bot: Telebot, update: Command) {.async.} =
  let url = update.message.text.get.replace("/geo", "").strip
  echo url
  if url.split(",").len == 2 and url.len < 20:
    let lat_lon = url.split(",")
    echo lat_lon
    if lat_lon.len == 2 and lat_lon[0].len > 2 and lat_lon[1].len > 2:
      echo lat_lon[0], lat_lon[1]
      handlerizerLocation():
        let latitud = parseFloat(lat_lon[0])
        let longitud = parseFloat(lat_lon[1])


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
  bot.onCommand("url", urlHandler)
  bot.onCommand("geo", geoHandler)
  bot.onCommand("uptime", uptimeHandler)
  #bot.onUpdate(handleUpdate)
  discard nice(19.cint)       # smooth cpu priority
  bot.poll(pollingInterval)


when isMainModule:
  waitFor main()
