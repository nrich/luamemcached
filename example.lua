#!/usr/bin/lua

local Memcached = require('Memcached')

local memcache = Memcached.Connect()

memcache:set('test', 'abc123')

print(memcache:get('test'))
