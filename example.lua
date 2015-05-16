#!/usr/bin/lua

local Memcached = require('Memcached')

local memcache = Memcached.Connect()

memcache:set('test', 'abc123')
memcache:set('test2', 'xyz321')

local foo = memcache:get_multi('test', 'test2')

for i,v in pairs(foo) do 
    print(i,v) 
end

print(memcache:get('test'))
