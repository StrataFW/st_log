fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'st_log'
author 'Strata Framework'
description 'Strata logging — pretty console + file + Discord + NDJSON, with dedup, size-based rotation, stack traces and live tail.'
version '1.0.0'
repository 'https://github.com/StrataFW/st_log'

files {
    'lib/init.lua',
    'server/format.lua',
    'server/buffer.lua',
    'server/file.lua',
    'server/player.lua',
    'server/dedup.lua',
    'server/webhook.lua',
    'server/redact.lua',
    'server/retention.lua',
    'server/emit.lua',
    'server/hooks.lua',
    'server/commands.lua',
}

server_scripts {
    'server/main.lua',
}
