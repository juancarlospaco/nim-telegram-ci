import
  asyncdispatch, httpclient, logging, json, options, osproc, strformat,
  strutils, times, random, posix, os, posix_utils, db_sqlite

import telebot, openexchangerates, openweathermap, zip/zipfiles, contra #, firejail

hardenedBuild()

include "constants.nim", "variables.nim"

var counter: int ## Integer that counts how many times the bot has been used.


template connectDb() =
  ## Connect the Database and injects a ``db`` variable with the ``DbConn``.
  var db {.inject.} = db_sqlite.open( "ci.db", "", "", "")

template generateDB(db: DbConn) =
  echo("Database: Generating database")
  if not db.tryExec(ciTable): echo("Database: CI table already exists")

connectDb()
generateDB(db)

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
  var msg = newPhoto(
    if declared(send2channel): channelUser else: update.message.chat.id,
    photo_path)
  msg.caption = photo_caption
  msg.disableNotification = true
  discard bot.send(msg)

template handlerizerLocation(body: untyped): untyped =
  ## This Template sends a Geo Location message from the ``latitud`` and ``longitud`` variables.
  inc counter
  body
  let
    geoUri = "*GEO URI:* geo:$1,$2    ".format(latitud, longitud)
    osmUrl = "*OSM URL:* https://www.openstreetmap.org/?mlat=$1&mlon=$2".format(
        latitud, longitud)
  var
    msg = newMessage(
      if declared(send2channel): channelUser else: update.message.chat.id,
      geoUri & osmUrl)
    geoMsg = newLocation(
      if declared(send2channel): channelUser else: update.message.chat.id,
      longitud, latitud)
  msg.disableNotification = true
  geoMsg.disableNotification = true
  msg.parseMode = "markdown"
  discard bot.send(geoMsg)
  discard bot.send(msg)

template handlerizerDocument(body: untyped): untyped =
  ## This Template sends an attached File Document message from the ``documentFilePath`` variable with the caption comment from ``documentCaption``.
  inc counter
  body
  var document = newDocument(
    if declared(send2channel): channelUser else: update.message.chat.id,
    "file://" & documentFilePath)
  document.caption = documentCaption.strip
  document.disableNotification = true
  discard bot.send(document)

proc aboutHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    let message = aboutText & $counter

proc donateHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():
    let message = "https://liberapay.com/juancarlospaco/donate"

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
    let send2channel = true
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
    moneyJson = waitFor oerClient.latest() # Updated Prices.
    nms = waitFor oerClient.currencies() # Friendly Names.
  var dineros = "*Dollar USD* 💲🇺🇸\n"
  for crrncy in moneyJson.pairs:
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
    msg.add file.quoteShell & "\n"
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
  handlerizer():
    let message = echoData

proc urlHandler(bot: Telebot, update: Command) {.async.} =
  let url = update.message.text.get.replace("/url", "").strip.quoteShell
  if url.startsWith("http://") or url.startsWith(
      "https://") and url.len < 1_000:
    if execCmdEx(cutycaptCmd & "--out=" & cutycaptPdf & " --url=" &
        url).exitCode == 0:
      handlerizerDocument():
        let documentFilePath = cutycaptPdf
        let documentCaption = url
    if execCmdEx(cutycaptCmd & "--out=" & cutycaptJpg & " --url=" &
        url).exitCode == 0:
      handlerizerDocument():
        let documentFilePath = cutycaptJpg
        let documentCaption = url
  else:
    handlerizer():
      let message = "*Syntax:*\n`/url https://YOUR-URL-HERE`"

proc geoHandler(bot: Telebot, update: Command) {.async.} =
  let url = update.message.text.get.replace("/geo", "").strip
  if url.split(",").len == 2 and url.len < 20:
    let latLon = url.split(",")
    if latLon.len == 2 and latLon[0].len > 2 and latLon[1].len > 2:
      handlerizerLocation():
        let latitud = parseFloat(latLon[0])
        let longitud = parseFloat(latLon[1])
  else:
    handlerizer():
      let message = "*Syntax:*\n`/geo 42.5,66.6`"

proc startHandler(bot: Telebot, update: Command) {.async.} =
  handlerizer():  # Show some explanations, wait 10 sec & continue.
    let message = msg0
  await sleepAsync(15_000)
  var  # Start just shows instructions to add a Git URL to the CI.
    mesage = newMessage(update.message.chat.id, msg1)
    b0 = initInlineKeyboardButton("NimScript Description")
    b1 = initInlineKeyboardButton("NimScript Functions")
    b2 = initInlineKeyboardButton("NimScript Project")
    b3 = initInlineKeyboardButton("CI Channel")
  b0.url = "https://nim-lang.org/docs/nims.html".some
  b1.url = "https://nim-lang.org/docs/nimscript.html".some
  b2.url = "https://github.com/kaushalmodi/nim_config#list-available-tasks".some
  b3.url = "https://t.me/s/NimArgentinaCI".some
  mesage.replyMarkup = newInlineKeyboardMarkup(@[b0, b1], @[b2, b3])
  discard await bot.send(mesage)

proc handleUpdate(bot: TeleBot, update: Update): UpdateCallback =
  ## Handler for all Updates, it does different simple actions based on the message received.
  inc counter
  echo update.message.get
  # var response = update.message.get
  # if unlikely(response.document.isSome):   # files
  #   var msg = newMessage(response.chat.id, "*NO Documents: Documents no, only Git HTTPS URLs!*") 
  #   msg.disableNotification = true
  #   msg.parseMode = "markdown"
  #   discard bot.send(msg)
  # elif response.text.isSome:   # Text Message.
  #   let url = response.text.get.strip.toLowerAscii
  #   let isUrl = countLines(url) == 1 and ' ' notin url and url.startsWith("https://")
  #   if isUrl:  # HTTPS URL Link.
  #     const sqlAddUrl = sql"INSERT INTO ci (url) VALUES (?)"
  #     var msg = newMessage(response.chat.id, "$(insertID(db, sqlAddUrl, url))") 
  #     msg.disableNotification = true
  #     msg.parseMode = "markdown"
  #     discard bot.send(msg)

proc buildRepo(url: string): bool =
  preconditions url.len > 0
  inc counter
  echo counter, url
  # Firejail
  # let myjail = Firejail(
  #   noAllusers = true, apparmor = true, caps = true, noMachineId  = true, 
  #   noMnt = true, noRamWriteExec = true, no3d = true, noDbus = true, 
  #   noDvd = true, noGroups = true, noNewPrivs = true, noRoot = true, 
  #   noSound = true, noAutoPulse = true, noVideo = true, forceEnUsUtf8 = true, 
  #   noU2f = true, privateTmp = true, private = true, privateCache = true,
  #   privateDev = true, noTv = true, writables = true, seccomp = true, 
  #   noShell = true, noX = true, noNet = true, noIp = true, noDebuggers = true, 
  #   appimage = false, newIpcNamespace = true, useMtuJumbo9000 = true, 
  #   useNice20 = true, useRandomMac = true,
  # )
  # let jailCmd = myjail.makeCommand(command: string,
  #   timeout = 99, maxOpenFiles = 99, maxPendingSignals = 9,
  #   dnsServers = ["1.1.1.1", "8.8.8.8", "8.8.4.4", "1.0.0.1"],
  # )
  # prepare firejail command
  # format a source code of a unittest, if needed
  # call subprocess via firejail
  # get result tuple and report
  # post report and result to channel
  # log result tuple
  # return result tuple


proc main() {.async.} =
  addHandler(newConsoleLogger(fmtStr = verboseFmtStr))
  addHandler(newRollingFileLogger())
  let bot = newTeleBot(apiKey)
  # Updates
  bot.onUpdate(handleUpdate)
  # No parameters
  bot.onCommand("start", startHandler)
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
  bot.onCommand("uptime", uptimeHandler)
  # Use parameters
  bot.onCommand("url", urlHandler)
  bot.onCommand("geo", geoHandler)
  discard nice(19.cint)       # smooth cpu priority
  bot.poll(pollingInterval)


when isMainModule:
  waitFor main()
