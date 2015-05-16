## Synopsis ##

```
require('Memcached')

memcache = Memcached.Connect('some.host.com', 11000)

memcache:set('some_key', 1234)
memcache:add('new_key', 'add new value')
memcache:replace('existing_key', 'replace old value')

cached_data = memcache:get('some_key')

memcache:delete('old_key')
```

### Methods ###

#### memcache = Memcached.Connect() ####
Connect to memcached server at localhost on port number 11211.

#### memcache = Memcached.Connect(host[, port]) ####
Connect to memcached server at 'host' on port number 'port'. If port is not provider, port 11211 is used.

#### memcache = Memcached.Connect(port) ####
Connect to memcached server at localhost on port number 'port'.

#### memcache = Memcached.Connect({{'host', port}, 'host', port}) ####
Connect to multiple memcached servers.

#### memcache:set(key, value[, expiry]) ####
Unconditionally sets a key to a given value in the memcache. The value for 'expiry' is the expiration time (default is 0, never expire).

#### memcache:add(key, value[, expiry]) ####
Like set, but only stores in memcache if the key doesn't already exist.

#### memcache:replace(key, value[, expiry]) ####
Like set, but only stores in memcache if the key already exists. The opposite of add.

#### value = memcache:get(key) ####
Retrieves a key from the memcache. Returns the value or nil

#### values = memcache:get\_multi(...) ####
Retrieves multiple keys from the memcache doing just one query. Returns a table of key/value pairs that were available.

#### memcache:delete(key) ####
Deletes a key. Returns true on deletion, false if the key was not found.

#### value = memcache:incr(key[, value]) ####
Sends a command to the server to atomically increment the value for key by value, or by 1 if value is nil. Returns nil if key doesn't exist on server, otherwise it returns the new value after incrementing. Value should be zero or greater.

#### value = memcache:decr(key[, value]) ####
Like incr, but decrements. Unlike incr, underflow is checked and new values are capped at 0. If server value is 1, a decrement of 2 returns 0, not -1.

#### servers = memcache:stats([key](key.md)) ####
Returns a table of statistical data regarding the memcache server(s). Allowed keys are:
'', 'malloc', 'sizes', 'slabs', 'items'

#### success = memcache:flush\_all() ####
Runs the memcached "flush\_all" command on all configured hosts, emptying all their caches.

#### memcache:disconnect\_all() ####
Closes all cached sockets to all memcached servers.

#### memcache:set\_hash(hashfunc) ####
Sets a custom hash function for key values. The default is a CRC32 hashing function.
'hashfunc' should be defined receiving a single string parameter and returing a single integer value.

#### memcache:set\_encode(func) ####
Sets a custom encode function for serialising table values. 'func' should be defined receiving a single
table value and returning a single string value.

#### memcache:set\_decode(func) ####
Sets a custom decode function for deserialising table values. 'func' should be defined receiving a single single and returning a single table value.

#### memcache:enable\_compression(onflag) ####
Turns data compression support on or off.

#### memcache:set\_compress\_threshold(size) ####
Set the compression threshold. If the value to be stored is larger than `size' bytes (and compression is enabled), compress before storing.

#### memcache:set\_compress(func) ####
Sets a custom data compression function. 'func' should be defined receiving a single string value and returning a single string value.

#### memcache:set\_decompress(func) ####
Sets a custom data decompression function. 'func' should be defined receiving a single string value and returning a single string value.