# Package

version       = "0.1.0"
author        = "Juan Carlos"
description   = "Telegram CI"
license       = "PPL"
srcDir        = "src"
bin           = @["nim_telegram_ci"]



# Dependencies

requires "nim >= 0.20.2"
requires "telebot"
requires "zip"
requires "webp"
requires "firejail"
requires "contra"
