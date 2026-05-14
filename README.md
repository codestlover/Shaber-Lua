<p align="center">
  <img src="./logo.webp" alt="Shaber" width="320">
</p>

# Shaber-Lua

Lua bindings for the Shaber API. Shaber is a JSON re-host of the
Spore.com archive: it pulls Spore's creaky XML/HTML endpoints and
re-emits them as clean, pretty-printed JSON, exposes the Sporepedia
catalog that the official site only hands out over DWR/AJAX, proxies the
Spore Fandom wiki across ten languages, and live-streams the OST as Opus
over WebSocket. This package wraps the whole surface so you don't have
to build HTTP/JSON/WS plumbing by hand.

Handy for:

- pulling creature, asset and sporecast data into Lua scripts
- mirroring or archiving Spore user pages
- grabbing wiki content without scraping HTML
- piping the OST into a player, recorder or shoutcast bridge

API:      https://shaber.sherolld.com
API DOCS: https://shaber.sherolld.com/docs

Want a client in a different language? Roll your own from
https://shaber.sherolld.com/docs.

Works on Lua 5.1, 5.3 and LuaJIT.

## Install

```bash
luarocks make shaber-0.0.0-0.rockspec
```

Or just drop `shaber.lua` and `shaber/radio.lua` somewhere on `package.path`.

Runtime deps: `luasocket`, `dkjson` (or `cjson`). The radio module also wants
`lua-websockets` and `luasec` (for `wss://`).

## Use it

```lua
local Shaber = require 'shaber'
local c = Shaber.new()

print(c:health().uptimeSeconds)
print(c:stats().totalUsers)
print(c:wikiRandom('en').title)
```

There's a method per endpoint, ~40 of them; names mirror the URLs, so
`/api/wiki/en/random` is `c:wikiRandom('en')`. All return parsed Lua
tables. Non-2xx replies bubble up through `error()` so wrap calls in
`pcall` if you want soft handling.

If you're hitting big endpoints, bump the timeout:

```lua
local c = Shaber.new{ timeout = 60 }
```

Full method reference, parameter docs and event payloads: [DOCS.md](./DOCS.md).

## Radio

```lua
local Radio = require 'shaber.radio'
local r = Radio.connect()

r:on('hello',  function(m) print(m.count, 'tracks') end)
r:on('track',  function(m) print(m.name) end)
r:on('binary', function(d) io.write(d) end)
r:on('end',    function() r:next() end)

r:run()
```

Commands: `next`, `prev`, `shuffle`, `order`, `pick(q)`, `list`, `close`.
Events: `hello`, `state`, `track`, `binary`, `end`, `interrupt`, `error`.

---

BSD-3-Clause.
