-- Shaber API client for Lua 5.1+ / LuaJIT.
-- Needs luasocket and a JSON parser (dkjson preferred, cjson works).
--
--   local Shaber = require 'shaber'
--   local c = Shaber.new()
--   print(c:health().uptimeSeconds)
--
-- Methods return a parsed Lua table on success and error() on non-2xx or
-- transport failure. Wrap in pcall if you want soft handling.

local http  = require 'socket.http'
local ltn12 = require 'ltn12'
local url   = require 'socket.url'

-- Try dkjson first, fall back to cjson if available.
local ok, json = pcall(require, 'dkjson')
if not ok then
  ok, json = pcall(require, 'cjson')
  if not ok then
    error("shaber: no JSON library found — install dkjson or lua-cjson")
  end
end

local Shaber = {}
Shaber.__index = Shaber

-- ---------------------------------------------------------------- helpers

local function encode_query(t)
  if t == nil then return nil end
  local parts = {}
  for k, v in pairs(t) do
    if v ~= nil then
      table.insert(parts, url.escape(tostring(k)) .. '=' .. url.escape(tostring(v)))
    end
  end
  if #parts == 0 then return nil end
  return table.concat(parts, '&')
end

local function escape_path(s)
  -- url.escape also escapes '/', so only use it on a single path segment.
  return url.escape(tostring(s))
end

-- ---------------------------------------------------------------- constructor

function Shaber.new(opts)
  local self = setmetatable({}, Shaber)
  opts = opts or {}
  self.baseUrl   = opts.baseUrl or 'https://shaber.sherolld.com'
  self.userAgent = opts.userAgent or 'shaber-lua'
  self.timeout   = opts.timeout or 30
  http.TIMEOUT = self.timeout
  return self
end

-- ---------------------------------------------------------------- low-level request

function Shaber:_get(path, query)
  local full = self.baseUrl .. path
  local qs = encode_query(query)
  if qs then full = full .. '?' .. qs end

  local sink_buf = {}
  local ok_req, code, _headers, status = http.request {
    url = full,
    method = 'GET',
    headers = {
      ['Accept']     = 'application/json',
      ['User-Agent'] = self.userAgent,
    },
    sink = ltn12.sink.table(sink_buf),
  }

  if not ok_req then
    error(string.format('shaber: transport failure on %s — %s', path, tostring(code)))
  end
  local body = table.concat(sink_buf)
  if code ~= 200 then
    error(string.format('shaber: HTTP %s on %s — %s', tostring(code), path,
                        (body or status or ''):sub(1, 200)))
  end
  if body == '' then return nil end
  local parsed, _, err = json.decode(body)
  if err then
    error(string.format('shaber: JSON parse error on %s — %s', path, tostring(err)))
  end
  return parsed
end

-- ---------------------------------------------------------------- meta

function Shaber:manifest() return self:_get('/api') end
function Shaber:health()   return self:_get('/api/health') end

-- ---------------------------------------------------------------- legacy mirror

function Shaber:stats()        return self:_get('/api/stats') end
function Shaber:creature(id)   return self:_get('/api/creatures/' .. escape_path(id)) end

function Shaber:asset(id)            return self:_get('/api/assets/' .. escape_path(id)) end
function Shaber:assetComments(id, start, len)
  return self:_get('/api/assets/' .. escape_path(id) .. '/comments',
                   {start = start, len = len})
end
function Shaber:assetDownload(id)    return self:_get('/api/assets/' .. escape_path(id) .. '/download') end
function Shaber:assetLineage(id)     return self:_get('/api/assets/' .. escape_path(id) .. '/lineage') end

function Shaber:user(name)           return self:_get('/api/users/' .. escape_path(name)) end
function Shaber:userAssets(name, start, len)
  return self:_get('/api/users/' .. escape_path(name) .. '/assets',
                   {start = start, len = len})
end
function Shaber:userSporecasts(name)
  return self:_get('/api/users/' .. escape_path(name) .. '/sporecasts')
end
function Shaber:userAchievements(name, start, len)
  return self:_get('/api/users/' .. escape_path(name) .. '/achievements',
                   {start = start, len = len})
end
function Shaber:userBuddies(name, start, len)
  return self:_get('/api/users/' .. escape_path(name) .. '/buddies',
                   {start = start, len = len})
end
function Shaber:userSubscribers(name, start, len)
  return self:_get('/api/users/' .. escape_path(name) .. '/subscribers',
                   {start = start, len = len})
end

function Shaber:sporecastAssets(id, start, len)
  return self:_get('/api/sporecasts/' .. escape_path(id) .. '/assets',
                   {start = start, len = len})
end

function Shaber:search(view, asset_type, start, len)
  return self:_get('/api/search',
                   {view = view, type = asset_type, start = start, len = len})
end

-- ---------------------------------------------------------------- Sporepedia extensions

function Shaber:searchText(q, asset_type) return self:_get('/api/search/text', {q = q, type = asset_type}) end
function Shaber:userTrophies(name)        return self:_get('/api/users/' .. escape_path(name) .. '/trophies') end
function Shaber:featuredAssets()          return self:_get('/api/featured/assets') end
function Shaber:featuredSporecasts()      return self:_get('/api/featured/sporecasts') end
function Shaber:trending(range)           return self:_get('/api/trending/' .. escape_path(range)) end
function Shaber:adventureLeaderboard(id, scope)
  return self:_get('/api/adventures/' .. escape_path(id) .. '/leaderboard', {scope = scope})
end
function Shaber:captain(assetId)          return self:_get('/api/captains/' .. escape_path(assetId)) end
function Shaber:userCaptain(name)         return self:_get('/api/users/' .. escape_path(name) .. '/captain') end
function Shaber:userStats(name)           return self:_get('/api/users/' .. escape_path(name) .. '/stats') end
function Shaber:tags()                    return self:_get('/api/tags') end

-- ---------------------------------------------------------------- wiki

function Shaber:wikiSearch(lang, q, limit, offset)
  return self:_get('/api/wiki/' .. lang .. '/search', {q = q, limit = limit, offset = offset})
end
function Shaber:wikiPage(lang, title, format)
  return self:_get('/api/wiki/' .. lang .. '/page/' .. escape_path(title),
                   {format = format or 'both'})
end
function Shaber:wikiRandom(lang) return self:_get('/api/wiki/' .. lang .. '/random') end
function Shaber:wikiCategory(lang, name, limit, cursor)
  return self:_get('/api/wiki/' .. lang .. '/category/' .. escape_path(name),
                   {limit = limit, cursor = cursor})
end
function Shaber:wikiRecent(lang, limit, cursor)
  return self:_get('/api/wiki/' .. lang .. '/recent', {limit = limit, cursor = cursor})
end
function Shaber:wikiPages(lang, limit, cursor)
  return self:_get('/api/wiki/' .. lang .. '/pages', {limit = limit, cursor = cursor})
end
function Shaber:wikiInfo(lang)  return self:_get('/api/wiki/' .. lang .. '/info') end
function Shaber:wikiLanglinks(lang, title)
  return self:_get('/api/wiki/' .. lang .. '/page/' .. escape_path(title) .. '/langlinks')
end
function Shaber:wikiCategories(lang, title)
  return self:_get('/api/wiki/' .. lang .. '/page/' .. escape_path(title) .. '/categories')
end
function Shaber:wikiBacklinks(lang, title, limit, cursor)
  return self:_get('/api/wiki/' .. lang .. '/page/' .. escape_path(title) .. '/backlinks',
                   {limit = limit, cursor = cursor})
end
function Shaber:wikiEmbeddedIn(lang, title, limit, cursor)
  return self:_get('/api/wiki/' .. lang .. '/page/' .. escape_path(title) .. '/embeddedin',
                   {limit = limit, cursor = cursor})
end
function Shaber:wikiImages(lang, limit, cursor)
  return self:_get('/api/wiki/' .. lang .. '/images', {limit = limit, cursor = cursor})
end
function Shaber:wikiFile(lang, name)
  return self:_get('/api/wiki/' .. lang .. '/file/' .. escape_path(name))
end

return Shaber
