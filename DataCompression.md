## Summary ##

LuaMemcached has the ability to compress and decompress data that is stored in the Memcache server. LuaMemcached provides callback functions to hook into the get and set methods for data retrieval and storage.

### Example ###

Perl's Cache::Memcached module compressed data in the Memcached server via in-memory GZIP files. To retrieve data from Lua that has been compressed via Perl (and vice-versa), the following callback functions can be used:

```
local Memcached = require('Memcached')
local zlib = require('zlib')

local m = Memcached.Connect()


m:set_decompress(function(str)
    return zlib.inflate(str):read('*a')
end)

m:set_compress(function(str)
    local buffer = {}

    local z = zlib.deflate(function(d)
        table.insert(buffer, d)
    end, nil, nil, 15 + 16)

    z:write(str)
    z:close()

    return table.concat(buffer)
end)

-- turn on compression
m:enable_compression(true)
```

**Please note** this requires the [lzlib](http://luaforge.net/projects/lzlib/) version 0.4 Lua module to be installed.