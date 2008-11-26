--Copyright (c) 2006,2007 Neil Richardson (nrich@iinet.net.au)
--
--Permission is hereby granted, free of charge, to any person obtaining a copy 
--of this software and associated documentation files (the "Software"), to deal
--in the Software without restriction, including without limitation the rights 
--to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
--copies of the Software, and to permit persons to whom the Software is 
--furnished to do so, subject to the following conditions:
--
--The above copyright notice and this permission notice shall be included in all
--copies or substantial portions of the Software.
--
--THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
--IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
--FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
--AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
--LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
--OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS 
--IN THE SOFTWARE.

module('Memcached', package.seeall)

require('socket')
require('CRC32')

local SERVER_RETRIES = 10

local STATS_KEYS = {
    malloc = true,
    sizes = true,
    slabs = true,
    items = true,
}

local function warn(str)
    io.stderr:write(string.format('%s\n', tostring(str)))
end

local function _select_server(cache, key)
    local server_count = #cache.servers

    local hashfunc = cache.hash or CRC32.Hash

    if server_count == 1 then
	return cache.servers[1].socket
    else
	local serverhash = hashfunc(key)

	for i = 0, SERVER_RETRIES do
	    local index = (serverhash % server_count) + 1
	    local server = cache.servers[index].socket

	    if not server then
		serverhash = hashfunc(serverhash .. i)
	    else
		return server
	    end
	end
    end

    error('No servers found')
    return nil
end

local function _retrieve(cache, key, str)
    local server = _select_server(cache, key)

    server:send(str .. '\r\n')

    local data = {}
    local key = nil
    while true do
	local line, err = server:receive()

	if line == 'END' then
	    break
	elseif string.sub(line, 1, 5) == 'VALUE' then
	    key = string.match(line, 'VALUE (%S+)')

	    data[key] = {}
	else
	    table.insert(data[key], line)
	end
    end

    local returndata = {}
    for k,d in pairs(data) do
	if d then
	    returndata[k] = table.concat(data[k], '\n')
	end
    end

    return returndata
end

local function _send(cache, key, str)
    local server = _select_server(cache, key)

    server:send(str .. "\r\n")
    local line, err = server:receive()
    
    if not err then return line end
end

local function _store(cache, op, key, value, expiry)
    local len = string.len(value)

    expiry = expiry or 0

    local cmd = op .. ' ' .. key .. ' 0 ' .. expiry .. ' ' .. len .. '\r\n' .. value

    local res = _send(cache, key, cmd)

    if res ~= 'STORED' then
	error("Error storing '" .. key .. "': " .. res)
	return false
    end

    return true
end

local function set(cache, key, value, expiry)
    return _store(cache, 'set', key, value, expiry)
end

local function add(cache, key, value, expiry)
    return _store(cache, 'add', key, value, expiry)
end

local function replace(cache, key, value, expiry)
    return _store(cache, 'replace', key, value, expiry)
end

local function get(cache, key)
    local dataset = _retrieve(cache, key, 'get ' .. key)
    return dataset[key]
end

local function delete(cache, key)
    local res = _send(cache, key, 'delete ' .. key)

    if res == 'NOT_FOUND' then
	return false
    end

    if res ~= 'DELETED' then
	error("Error deleting '" .. key .. "': " .. res)
	return false
    end

    return true
end

local function incr(cache, key, val)
    val = val or 1
	
    local res = _send(cache, key, 'incr ' .. key .. ' ' .. val)

    if res == 'ERROR' or res == 'CLIENT_ERROR' then
	error("Error incrementing '" .. key .. "': " .. res)
    end

    return res
end

local function decr(cache, key, val)
    val = val or 1

    local res = _send(cache, key, 'decr ' .. key .. ' ' .. val)

    if res == 'ERROR' or res == 'CLIENT_ERROR' then
	error("Error incrementing '" .. key .. "': " .. res)
    end

    return res
end

local function stats(cache, key)
    local servers = {}

    key = key or ''

    if string.len(key) > 0 and not STATS_KEYS[key] then
	error(string.format("Unknown stats key '%s'", key))
    end

    for i,server in pairs(cache.servers) do
	server.socket:send('stats ' .. key .. '\r\n')

	local stats = {}

	while true do
	    local line, err = server.socket:receive()

	    if line == 'END' or line == 'ERROR' then
		break
	    end

	    local k,v = string.match(line, 'STAT (%S+) (%S+)')

	    if k then
		stats[k] = v
	    end
	end

	servers[server.name] = stats
    end

    return servers
end 

local function get_multi(cache, ...)

    local dataset = nil
    if table.maxn(cache.servers) > 1 then
	dataset = {}

	for i,k in ipairs(arg) do
	    local data = _retrieve(cache, k, 'get ' .. k)
	    dataset[k] = data[k]
	end
    else
	local keys = table.concat(arg, ' ')
	dataset = _retrieve(cache, keys, 'get ' .. keys)
    end

    return dataset
end

local function flush_all(cache)
    local success = true

    for i,server in ipairs(cache.servers) do
	server.socket:send('flush_all\r\n')
	local res = assert(server.socket:receive())

	if res ~= 'OK' then
	    success = false
	end
    end

    return success
end

local function disconnect_all(cache)
    while true do
	local server = table.remove(cache.servers)

	if not server then
	    break
	end

	server.socket:close()
    end    
end

local function set_hash(cache, hashfunc)
    cache.hash = hashfunc
end

function Connect(hostlist, port)
    local servers = {}

    if type(hostlist) == 'table' then
	for i,host in pairs(hostlist) do
	    local h, p

	    if type(host) == 'table' then
		h = host[1]
		p = host[2]
	    elseif type(host) == 'string' then
		h = host
	    elseif type(host) == 'number' then
		p = host
		h = nil
	    end

	    if not h then
		h = '127.0.0.1'
	    end

	    if not p then 
		p = 11211
	    end

	    local server = socket.connect(h, p)

	    if not server then
		warn('Could not connect to ' .. h .. ':' .. p)
	    else
		table.insert(servers, {socket = server, name = string.format('%s:%d', h, p)})
	    end
	end
    else
	local address = hostlist

	if type(address) == 'number' then
	    port = address
	    address = nil
	end

	if address == nil then
	    address = '127.0.0.1'
	end

	if port == nil then
	    port = 11211
	end

	local server = socket.connect(address, port)

	if not server then
	    warn('Could not connect to ' .. address .. ':' .. port)
	else
	    servers = {{socket = server, name = string.format('%s:%d', address, port)}}
	end
    end

    if table.maxn(servers) < 1 then
	error('No servers available')
    end

    local cache = {
	servers = servers,

	set_hash = set_hash,
	hash = nil,

	set = set,
	add = add,
	replace = replace,
	get = get,
	delete = delete,
	incr = incr,
	decr = decr,

	get_multi = get_multi,
	stats = stats,
	flush_all = flush_all,
	disconnect_all = disconnect_all,
    }

    return cache
end

function New(hostlist, port)
    return Connect(hostlist, port)
end

-- 
-- Memcached.lua
-- 
-- A pure Lua implementation of a simple memcached client. 1 or more memcached server(s) are currently supported. Requires the luasocket library.
-- See http://www.danga.com/memcached/ for more information about memcached.
--
--
--
-- Synopsis
--
-- require('Memcached')
--
-- memcache = Memcached.Connect('some.host.com', 11000)
--    OR
-- memcache = Memcached.New('some.host.com', 11000)
--
-- memcache:set('some_key', 1234)
-- memcache:add('new_key', 'add new value')
-- memcache:replace('existing_key', 'replace old value')
--
-- cached_data = memcache:get('some_key')
--
-- memcache:delete('old_key')
--
--
--
-- Methods:
--
-- memcache = Memcached.Connect()
--    Connect to memcached server at localhost on port number 11211. 
--
-- memcache = Memcached.Connect(host[, port])
--    Connect to memcached server at 'host' on port number 'port'. If port is not provided, port 11211 is used.  
--
---memcache = Memcached.Connect(port)
--    Connect to memcached server at localhost on port number 'port'.
--
-- memcache = Memcached.Connect({{'host', port}, 'host', port})  
--    Connect to multiple memcached servers.
--
-- memcache:set(key, value[, expiry])
--    Unconditionally sets a key to a given value in the memcache. The value for 'expiry' is the expiration
--    time (default is 0, never expire).
--     
-- memcache:add(key, value[, expiry])
--    Like set, but only stores in memcache if the key doesn't already exist.
--    
-- memcache:replace(key, value[, expiry])
--    Like set, but only stores in memcache if the key already exists. The opposite of add.
--    
-- value = memcache:get(key)
--    Retrieves a key from the memcache. Returns the value or nil
--    
-- values = memcache:get_multi(...)
--    Retrieves multiple keys from the memcache doing just one query.  Returns a table of key/value pairs that were available.
--    
-- memcache:delete(key)
--    Deletes a key. Returns true on deletion, false if the key was not found.
--    
-- value = memcache:incr(key[, value])
--    Sends a command to the server to atomically increment the value for key by value, or by 1 if value is nil. 
--    Returns nil if key doesn't exist on server, otherwise it returns the new value after incrementing. Value should be zero or greater.
--    
-- value = memcache:decr(key[, value])
--    Like incr, but decrements. Unlike incr, underflow is checked and new values are capped at 0. If server value is 1, a decrement of 2 returns 0, not -1.
--
-- servers = memcache:stats([key])
--    Returns a table of statistical data regarding the memcache server(s). Allowed keys are:
--	'', 'malloc', 'sizes', 'slabs', 'items'
--
--  success = memcache:flush_all()
--     Runs the memcached "flush_all" command on all configured hosts, emptying all their caches. 
--
--  memcache:disconnect_all()
--     Closes all cached sockets to all memcached servers.
--
--  memcache:set_hash(hashfunc)
--     Sets a custom hash function for key values. The default is a CRC32 hashing function.
--     'hashfunc' should be defined receiving a single string parameter and returing a single integer value.
