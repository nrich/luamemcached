## Summary ##

### Example ###

```
local Memcached = require('Memcached')
local json = require('json')

local m = Memcached.Connect()

m:set_encode(json.encode)
m:set_decode(json.decode)

-- implicitly calls the 'encode' function above
m:set('some_key', {a = 1, b = 2, c = 3})

-- implicitly calls the 'decode' function above
local obj = m:get('some_key')

```