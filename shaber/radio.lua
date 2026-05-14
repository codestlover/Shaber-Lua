-- WebSocket client for Shaber's /api/radio.
--
-- Needs lua-websockets for framing, plus luasec for wss://. The HTTP client
-- in `shaber` works without either.
--
--   local Radio = require 'shaber.radio'
--   local r = Radio.connect()    -- wss://shaber.sherolld.com/api/radio
--   r:on('hello', function(m) print('catalog:', m.count) end)
--   r:on('track', function(m) print('now playing:', m.name) end)
--   r:on('end',   function()  r:next() end)
--   r:on('binary',function(d) os.write(d) end)
--   r:run()
--
-- r:run() blocks until the peer closes or you call r:close(). After that the
-- connection is dead; call Radio.connect again to reconnect.

local socket = require 'socket'
local sync   = require 'websocket.sync'
local tools  = require 'websocket.tools'

local ok, json = pcall(require, 'dkjson')
if not ok then json = require 'cjson' end

local Radio = {}
Radio.__index = Radio

local EVENTS = {'hello', 'state', 'track', 'end', 'interrupt', 'error', 'binary'}

-- Plain ws:// transport (mirrors websocket.client_sync exactly).
local function plain_client(opts)
  local self = {}
  self.sock_connect = function(self_, host, port)
    self_.sock = socket.tcp()
    if opts.timeout then self_.sock:settimeout(opts.timeout) end
    local _, err = self_.sock:connect(host, port)
    if err then self_.sock:close(); return nil, err end
  end
  self.sock_send    = function(self_, ...) return self_.sock:send(...) end
  self.sock_receive = function(self_, ...) return self_.sock:receive(...) end
  self.sock_close   = function(self_) self_.sock:close() end
  return sync.extend(self)
end

-- wss:// transport. lua-websockets' shipped client_sync is plaintext-only,
-- so we wrap the TCP socket with luasec to terminate TLS before handing
-- the byte stream to the WebSocket framing layer.
local function tls_client(opts)
  local ssl = require 'ssl'
  local self = {}
  self.sock_connect = function(self_, host, port)
    local tcp = socket.tcp()
    if opts.timeout then tcp:settimeout(opts.timeout) end
    local _, err = tcp:connect(host, port)
    if err then tcp:close(); return nil, err end
    local wrapped, werr = ssl.wrap(tcp, {
      mode     = 'client',
      protocol = 'any',
      verify   = 'none',     -- ZeroSSL/LE chain locations vary across distros
      options  = 'all',
    })
    if not wrapped then tcp:close(); return nil, werr end
    wrapped:sni(host)
    local ok_, herr = wrapped:dohandshake()
    if not ok_ then wrapped:close(); return nil, herr end
    self_.sock = wrapped
  end
  self.sock_send    = function(self_, ...) return self_.sock:send(...) end
  self.sock_receive = function(self_, ...) return self_.sock:receive(...) end
  self.sock_close   = function(self_) self_.sock:close() end
  return sync.extend(self)
end

-- Derive a ws(s):// URL from an http(s):// base URL. Lets callers pass
-- `baseUrl = client.baseUrl` and get the matching radio URL automatically.
local function derive_ws_url(base)
  local scheme, rest = base:match('^(https?)://(.*)$')
  if not scheme then return base end  -- already ws/wss; trust the caller
  local ws = scheme == 'https' and 'wss' or 'ws'
  return ws .. '://' .. rest:gsub('/$', '') .. '/api/radio'
end

function Radio.connect(opts)
  opts = opts or {}
  local self = setmetatable({}, Radio)
  self.handlers = {}
  for _, ev in ipairs(EVENTS) do self.handlers[ev] = {} end

  local target = opts.url
    or (opts.baseUrl and derive_ws_url(opts.baseUrl))
    or 'wss://shaber.sherolld.com/api/radio'

  local scheme, host, port, uri = tools.parse_url(target)
  if scheme ~= 'ws' and scheme ~= 'wss' then
    error("shaber.radio: bad scheme '" .. tostring(scheme) .. "' — expected ws or wss")
  end

  -- websocket.sync hard-rejects anything other than 'ws://' in its connect()
  -- check, so we always feed it a ws:// URL. The transport choice (plain vs
  -- TLS) is decided here via which sock_* callbacks we install.
  local plain_url = 'ws://' .. host .. ':' .. tostring(port) .. uri
  self.ws = scheme == 'wss' and tls_client(opts) or plain_client(opts)

  local ok_, err = self.ws:connect(plain_url)
  if not ok_ then
    error('shaber.radio: connect failed — ' .. tostring(err))
  end
  return self
end

function Radio:on(event, fn)
  if not self.handlers[event] then
    error("shaber.radio: unknown event '" .. tostring(event) .. "'")
  end
  table.insert(self.handlers[event], fn)
  return self
end

local function dispatch(self, event, payload)
  for _, fn in ipairs(self.handlers[event] or {}) do
    local ok_, err = pcall(fn, payload)
    if not ok_ then
      io.stderr:write('shaber.radio: handler for ' .. event .. ' threw: ' .. tostring(err) .. '\n')
    end
  end
end

function Radio:send(cmd) return self.ws:send(cmd) end
function Radio:next()    return self:send('next') end
function Radio:prev()    return self:send('prev') end
function Radio:shuffle() return self:send('shuffle') end
function Radio:order()   return self:send('order') end
function Radio:list()    return self:send('list') end
function Radio:pick(q)   return self:send('=' .. tostring(q)) end

function Radio:close()
  local w = self.ws
  if w then self.ws = nil; pcall(w.close, w) end
end

-- Blocking event loop. Reads frames until peer closes or close() is called.
function Radio:run()
  while self.ws do
    local data, opcode_or_err = self.ws:receive()
    if not data then
      dispatch(self, 'error', {type = 'error', message = tostring(opcode_or_err)})
      break
    end
    -- lua-websockets reports opcode 1 = text, 2 = binary
    if opcode_or_err == 2 then
      dispatch(self, 'binary', data)
    else
      local msg, _, err = json.decode(data)
      if err then
        dispatch(self, 'error', {type = 'error', message = 'bad json: ' .. tostring(err)})
      elseif msg and msg.type then
        dispatch(self, msg.type, msg)
      end
    end
  end
end

return Radio
