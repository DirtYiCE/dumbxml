-- This program is free software. It comes without any warranty, to
-- the extent permitted by applicable law. You can redistribute it
-- and/or modify it under the terms of the Do What The Fuck You Want
-- To Public License, Version 2, as published by Sam Hocevar. See
-- http://sam.zoy.org/wtfpl/COPYING for more details.

require 'dumbxml'

-- count number of elements in a table
function tblcnt(tbl)
  local n = 0
  for k,v in pairs(tbl) do n = n + 1 end
  return n
end

local dxml = require('dumbxml')

-- make sure alternative names are actually the same
assert(dxml.START_TAG == dxml.START_ELEMENT)
assert(dxml.END_TAG == dxml.END_ELEMENT)

--------------------------------------------------------------------------------
-- standard parsing

print('simple xml parsing')
local f = dxml.fromString('<foo>foobar</foo>')
local i = f:next()
assert(i.type == dxml.START_TAG)
assert(i.name == 'foo')
assert(next(i.attrs) == nil)

i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == 'foobar')

i = f:next()
assert(i.type == dxml.END_TAG)
assert(i.name == 'foo')

assert(f:next() == nil)

--------------------------------------------------------------------------------
print('shorthand tag close')
f = dxml.fromString('asd<foo />bar')
i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == 'asd')

i = f:next()
assert(i.type == dxml.START_TAG)
assert(i.name == 'foo')
assert(next(i.attrs) == nil)

i = f:next()
assert(i.type == dxml.END_TAG)
assert(i.name == 'foo')

i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == 'bar')

assert(f:next() == nil)

--------------------------------------------------------------------------------
print('attributes')
f = dxml.fromString('<foo abc="def" ghi=jkl xyz>baz</foo>')
i = f:next()
assert(i.type == dxml.START_TAG)
assert(i.name == 'foo')
assert(i.attrs)
assert(i.attrs.abc == 'def')
assert(i.attrs.ghi == 'jkl')
assert(i.attrs.xyz == 'xyz')
assert(tblcnt(i.attrs) == 3)

--------------------------------------------------------------------------------
print('nested tags')
f = dxml.fromString('<foo>bar<ze>zem<xyz /></ze>o</foo>')
i = f:next()
assert(i.type == dxml.START_TAG)
assert(i.name == 'foo')
assert(tblcnt(i.attrs) == 0)

i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == 'bar')

i = f:next()
assert(i.type == dxml.START_TAG)
assert(i.name == 'ze')
assert(tblcnt(i.attrs) == 0)

i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == 'zem')

i = f:next()
assert(i.type == dxml.START_TAG)
assert(i.name == 'xyz')
assert(tblcnt(i.attrs) == 0)

i = f:next()
assert(i.type == dxml.END_TAG)
assert(i.name == 'xyz')

i = f:next()
assert(i.type == dxml.END_TAG)
assert(i.name == 'ze')

i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == 'o')

i = f:next()
assert(i.type == dxml.END_TAG)
assert(i.name == 'foo')

assert(f:next() == nil)

--------------------------------------------------------------------------------
print('entities')
f = dxml.fromString('foo &amp; bar &lt;3')
i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == 'foo & bar <3')

assert(f:next() == nil)

--------------------------------------------------------------------------------
print('entities in attributes')
f = dxml.fromString('<foo bar="asd&quot;ef" />')
i = f:next()
assert(i.type == dxml.START_TAG)
assert(i.name == 'foo')
assert(tblcnt(i.attrs) == 1)
assert(i.attrs.bar == 'asd"ef')

i = f:next()
assert(i.type == dxml.END_TAG)
assert(i.name == 'foo')

assert(f:next() == nil)

--------------------------------------------------------------------------------
-- error handling
print('unfinished tag')
f = dxml.fromString('<foo')
assert(pcall(function() f:next() end) == false)
assert(f:next() == nil)

print('ignore errors')
f = dxml.fromString('<foo', { error = function() end })
i = f:next()
assert(i.type == dxml.START_TAG)
assert(i.name == 'foo')
assert(f:next() == nil)

print('entity error')
f = dxml.fromString('foo &lt bar', { error = function() end })
i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == 'foo &lt bar')
assert(f:next() == nil)

--------------------------------------------------------------------------------
-- customization
print('handle unknown entities')
local function unkent(obj, ent)
  return '['..ent..']'
end

f = dxml.fromString('foo &lt; bar &hah; gx &df;', { unknown_entity = unkent })
i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == 'foo < bar [hah] gx [df]')
assert(f:next() == nil)

print('custom entities')
local ent = { a = '$a', b = '*b' }
f = dxml.fromString('a&a;b&b;', { entities = ent })
i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == 'a$ab*b')
assert(f:next() == nil)

print('no more default entities')
f = dxml.fromString('&amp;', { entities = ent })
assert(pcall(function() f:next() end) == false)
assert(f:next() == nil)

--------------------------------------------------------------------------------
print('custom character set')
local tbl = {
  tag_separator_start = '[',
  tag_separator_end = ']',
  tag_terminate = '!',
  tag_whitespace = '_b',
  tag_eq = '*',
  tag_quote = '@^',
  entity_start = '~',
  entity_end = '?',
}
-- it don't even resemble xml, but we only changed some letters...
f = dxml.fromString('[foo][embxs*asd_foo*@abc@baab!]gh~amp?[!foo]', tbl)
i = f:next()
assert(i.type == dxml.START_TAG)
assert(i.name == 'foo')
assert(tblcnt(i.attrs) == 0)

i = f:next()
assert(i.type == dxml.START_TAG)
assert(i.name == 'em')
assert(i.attrs.xs == 'asd')
assert(i.attrs.foo == 'abc')
assert(i.attrs.aa == 'aa')
assert(tblcnt(i.attrs) == 3)

i = f:next()
assert(i.type == dxml.END_TAG)
assert(i.name == 'em')

i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == 'gh&')

i = f:next()
assert(i.type == dxml.END_TAG)
assert(i.name == 'foo')

assert(f:next() == nil)

--------------------------------------------------------------------------------
print('no entity replacing in text')
f = dxml.fromString('abc &amp; def &lt;', { entity_replace = false })
i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == 'abc ')

i = f:next()
assert(i.type == dxml.ENTITY)
assert(i.name == 'amp')
assert(i.value == '&')

i = f:next()
assert(i.type == dxml.TEXT)
assert(i.text == ' def ')

i = f:next()
assert(i.type == dxml.ENTITY)
assert(i.name == 'lt')
assert(i.value == '<')

assert(f:next() == nil)

--------------------------------------------------------------------------------
print('iterating')
f = dxml.fromString('<foo><foo><foo>')
local n = 0
for i in f:iter() do
  assert(i.type == dxml.START_TAG)
  assert(i.name == 'foo')
  n = n + 1
end
assert(n == 3)
