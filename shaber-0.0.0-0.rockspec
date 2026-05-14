package = "shaber"
version = "0.0.0-0"

source = {
  url = "git+https://example.invalid/shaber.git",
  tag = "v0.0.0",
}

description = {
  summary  = "Shaber API client — Lua bindings for the Spore archive that talks JSON.",
  detailed = [[
    Wraps every endpoint of the Shaber HTTP API (the legacy Spore.com REST
    mirror, Sporepedia gap endpoints, and the multilingual Fandom wiki proxy)
    plus the /api/radio WebSocket stream. Returns parsed Lua tables; raises on
    non-200 responses.
  ]],
  homepage = "https://github.com/misa/shaber",
  license  = "BSD-3-Clause",
}

dependencies = {
  "lua >= 5.1",
  "luasocket",
  "dkjson",
  -- Optional for shaber.radio:
  --   "lua-websockets >= 2.0",  -- WebSocket framing
  --   "luasec",                 -- TLS, required for the wss:// connection
}

build = {
  type = "builtin",
  modules = {
    ["shaber"]        = "shaber.lua",
    ["shaber.radio"]  = "shaber/radio.lua",
  },
}
