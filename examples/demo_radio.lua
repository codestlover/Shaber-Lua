-- Run: cd .. && lua examples/demo_radio.lua
-- Needs lua-websockets and luasec for wss://.
--   luarocks install lua-websockets luasec
package.path = '../?.lua;../?/init.lua;' .. package.path

local Radio = require 'shaber.radio'

local r = Radio.connect()

local bytes_received = 0
local tracks_played  = 0
local target = 2  -- stop after 2 tracks for a smoke run

r:on('hello',     function(m) print('catalog has', m.count, 'tracks') end)
r:on('state',     function(m) print('mode:', m.mode) end)
r:on('track',     function(m) print('▶', string.format('#%03d %s', m.index, m.name)); bytes_received = 0 end)
r:on('binary',    function(d) bytes_received = bytes_received + #d end)
r:on('end',       function()
  tracks_played = tracks_played + 1
  print('  end of track ('..bytes_received..' bytes)')
  if tracks_played >= target then
    print('done — closing')
    r:close()
  else
    r:next()
  end
end)
r:on('interrupt', function() print('  interrupt') end)
r:on('error',     function(m) print('!', m.message) end)

r:run()
