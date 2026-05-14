-- Run: cd .. && lua examples/demo_http.lua
-- Hits https://shaber.sherolld.com.
package.path = '../?.lua;' .. package.path

local Shaber = require 'shaber'
local c = Shaber.new()

print('--- health ---')
local h = c:health()
print(string.format('ok=%s  uptime=%.1fs', tostring(h.ok), h.uptimeSeconds))

print('\n--- stats ---')
local s = c:stats()
print(string.format('totalUploads=%d  totalUsers=%d  dayUsers=%d', s.totalUploads, s.totalUsers, s.dayUsers))

print('\n--- wiki: random article (en) ---')
local r = c:wikiRandom('en')
print(string.format('#%d  %s', r.pageid, r.title))

print('\n--- user: MaxisDangerousYams ---')
local ok, u = pcall(function() return c:user('MaxisDangerousYams') end)
if ok then
  print(string.format('id=%s  tagline=%q', u.id, u.tagline))
else
  print('skipped: ' .. tostring(u))
end

print('\n--- tags (cloud, top 10) ---')
local t = c:tags()
if t and t.tags then
  for i = 1, math.min(10, #t.tags) do
    local row = t.tags[i]
    print(string.format('  %-20s %d', row.name, row.count))
  end
end
