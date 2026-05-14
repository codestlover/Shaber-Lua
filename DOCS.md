# Shaber-Lua docs

A walkthrough of every method on the Shaber Lua client, grouped by what they
talk to on the server. Response shapes (JSON keys, types, what each field
means) live in the API docs at https://shaber.sherolld.com/docs. This page
covers the Lua side: function signatures, what they take, what they return.

## Setup

```lua
local Shaber = require 'shaber'
local c = Shaber.new()
```

`Shaber.new` accepts an options table:

```lua
Shaber.new{
  userAgent = 'my-bot',  -- defaults to 'shaber-lua'
  timeout   = 30,        -- seconds; defaults to 30
}
```

Every method below returns a parsed Lua table on success. Non-2xx responses
raise via `error()` — wrap in `pcall` for soft handling:

```lua
local ok, result = pcall(function() return c:user('does-not-exist') end)
if not ok then
  print('error:', result)
end
```

## Meta

| Method | What it does |
|---|---|
| `c:manifest()` | The self-describing manifest at `/api`. List of every endpoint with method, path, summary, category. |
| `c:health()`   | Liveness check. `{ok, uptimeSeconds}`. |

## Daily stats

| Method | What it does |
|---|---|
| `c:stats()` | One-shot snapshot of the Spore.com counters (uploads, users, ratings, ...). Cached upstream for 5 min. |

## Creatures

| Method | What it does |
|---|---|
| `c:creature(id)` | The full attribute sheet for a creature: stats, parts, tags, dimensions. |

## Assets

These cover every kind of asset (creatures, vehicles, buildings, adventures,
captains, sporecasts).

| Method | What it does |
|---|---|
| `c:asset(id)`                            | Asset metadata: id, type, name, tagline, owner, ratings, tags. |
| `c:assetComments(id, start, len)`        | Comment thread on an asset. Pagination via `start` (default 0) and `len` (default 10, max 100). |
| `c:assetDownload(id)`                    | The legacy XML payload (`xml_data`) needed to import an asset back into Spore. |
| `c:assetLineage(id)`                     | The parent/remix chain of an asset. |

## Users

| Method | What it does |
|---|---|
| `c:user(name)`                            | User profile: id, tagline, image. |
| `c:userAssets(name, start, len)`          | Assets the user uploaded. |
| `c:userSporecasts(name)`                  | Sporecasts the user owns. |
| `c:userAchievements(name, start, len)`    | Achievement history. |
| `c:userBuddies(name, start, len)`         | Outgoing buddy list. |
| `c:userSubscribers(name, start, len)`     | Users subscribed to this one. |
| `c:userTrophies(name)`                    | Trophies / badges. |
| `c:userCaptain(name)`                     | The user's space-stage captain (if any). |
| `c:userStats(name)`                       | Aggregate counts: uploads, downloads, subscribers, total ratings. |

## Sporecasts

| Method | What it does |
|---|---|
| `c:sporecastAssets(id, start, len)` | Every asset in a sporecast. |

## Search & catalog

| Method | What it does |
|---|---|
| `c:search(view, type, start, len)` | Browse-style search. `view` is the sort (e.g. `'NEWEST'`, `'TOP_RATED'`), `type` filters by asset kind. |
| `c:searchText(q, type)`            | Full-text Sporepedia search for `q`. |
| `c:trending(range)`                | Trending uploads. `range` is one of `'today'`, `'week'`, `'month'`, ...|
| `c:featuredAssets()`               | Maxis-featured assets. |
| `c:featuredSporecasts()`           | Maxis-featured sporecasts. |
| `c:tags()`                         | The site-wide tag cloud, sorted by use count. |

## Adventures & captains

| Method | What it does |
|---|---|
| `c:adventureLeaderboard(id, scope)` | Leaderboard rows for an adventure. `scope` is `'global'` or `'friends'`. |
| `c:captain(assetId)`                | Captain build for an asset id (the space-stage incarnation). |

## Wiki

The Spore Fandom MediaWiki proxied across ten languages. `lang` is a
two-letter code: `en`, `de`, `es`, `fr`, `it`, `ja`, `pl`, `pt`, `ru`, `zh`.

| Method | What it does |
|---|---|
| `c:wikiSearch(lang, q, limit, offset)`    | Full-text wiki search. |
| `c:wikiPage(lang, title, format)`         | Fetch a page. `format` is `'html'`, `'wikitext'` or `'both'` (default). |
| `c:wikiRandom(lang)`                      | A random page. |
| `c:wikiCategory(lang, name, limit, cursor)` | Members of a category. |
| `c:wikiRecent(lang, limit, cursor)`       | Recent edits. |
| `c:wikiPages(lang, limit, cursor)`        | All pages (paginated). |
| `c:wikiInfo(lang)`                        | Per-language wiki stats: page count, edits, users. |
| `c:wikiLanglinks(lang, title)`            | Translations of a page in other languages. |
| `c:wikiCategories(lang, title)`           | Categories a page belongs to. |
| `c:wikiBacklinks(lang, title, limit, cursor)` | Pages that link to this one. |
| `c:wikiEmbeddedIn(lang, title, limit, cursor)` | Pages that transclude this template. |
| `c:wikiImages(lang, limit, cursor)`       | Image files on the wiki. |
| `c:wikiFile(lang, name)`                  | Metadata + URL for a single image. |

Pagination knobs vary by endpoint: most accept `limit` + `cursor` (server
returns the next cursor in the response), a few use `start` + `len`.

## Radio

The `/api/radio` WebSocket lives in a sub-module. It connects to
`wss://shaber.sherolld.com/api/radio`:

```lua
local Radio = require 'shaber.radio'
local r = Radio.connect()
```

`Radio.connect` accepts an options table with `timeout = <seconds>`.

### Event handlers

```lua
r:on(event, fn)
```

Events:

| Event | Payload | When |
|---|---|---|
| `hello`     | `{count, tracks=[...]}` | Once per connection. `tracks` is the full catalog: `{index, name, file, mime, bytes}` per track. |
| `state`     | `{mode}`                | Mode change (`'order'` or `'shuffle'`). |
| `track`     | `{index, name, file, mime, bytes}` | Server is about to send a new track. |
| `binary`    | raw bytes (string)      | An audio chunk. Concatenate them until `end`. |
| `end`       | (no payload)            | Current track fully delivered. |
| `interrupt` | (no payload)            | Track aborted because you sent `next`/`prev`/`=q`. |
| `error`     | `{message}`             | Server-side or socket error. |

### Commands

| Method | Wire | Effect |
|---|---|---|
| `r:next()`     | `next`     | Advance one track. |
| `r:prev()`     | `prev`     | Back one track. |
| `r:shuffle()`  | `shuffle`  | Toggle shuffle on. |
| `r:order()`    | `order`    | Toggle shuffle off. |
| `r:list()`     | `list`     | Re-send the `hello` catalog. |
| `r:pick(q)`    | `=<q>`     | Jump to the first track whose filename contains `q`. |
| `r:close()`    | --         | Graceful shutdown of the socket. |

### Event loop

`r:run()` blocks, reading frames until the peer closes or you call
`r:close()`. After it returns the connection is dead — make a new
`Radio.connect` to reconnect.

```lua
local r = Radio.connect()
local audio = io.open('out.opus', 'wb')

r:on('hello',  function(m) print('catalog:', m.count) end)
r:on('track',  function(m) print('▶', m.name) end)
r:on('binary', function(d) audio:write(d) end)
r:on('end',    function() r:next() end)
r:run()

audio:close()
```

## Errors

`error()` is raised for transport failures and non-2xx HTTP responses. The
message includes the HTTP status, path and (the first 200 chars of) the
response body, e.g.

```
shaber: HTTP 404 on /api/users/does-not-exist — User not found
```
