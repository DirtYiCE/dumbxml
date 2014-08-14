-- Small and dumb xml like parsing

-- This program is free software. It comes without any warranty, to
-- the extent permitted by applicable law. You can redistribute it
-- and/or modify it under the terms of the Do What The Fuck You Want
-- To Public License, Version 2, as published by Sam Hocevar. See
-- http://sam.zoy.org/wtfpl/COPYING for more details.

local dumbxml = {
  START_TAG = 0,
  START_ELEMENT = 0, -- SAX terminology
  TEXT = 1,
  END_TAG = 2,
  END_ELEMENT = 2,
  ENTITY = 3, -- only if entity_replace = false

  tag_separator_start = '<',
  tag_separator_end   = '>',
  tag_terminate       = '/',
  tag_whitespace      = ' \t\r\n',
  tag_eq              = '=',
  tag_quote           = '\'"',
  entity_start        = '&',
  entity_end          = ';',
  entities = {
    -- most commonly used entities, you can add more as you like
    amp  = '&',
    lt   = '<',
    gt   = '>',
    apos = "'",
    quot = '"',
  },
  unknown_entity = function(obj, entity)
    obj.error("unknown entity "..entity)
    return obj.entity_start..entity..obj.entity_end
  end,

  error = error,

  -- if true, entities are replaced everywhere with their values; if false, only
  -- in arguments
  entity_replace = true,
}
dumbxml.__index = dumbxml

local TBL_TYPES = { 'tag_whitespace', 'tag_quote' }
function dumbxml.new(obj)
  setmetatable(obj, dumbxml)

  for _,typ in ipairs(TBL_TYPES) do
    if type(obj[typ]) == 'string' then
      local tbl = {}
      for c in obj[typ]:gmatch('.') do
        tbl[c] = true
      end
      obj[typ] = tbl
    end
  end

  return obj
end

function dumbxml.fromString(str, obj)
  obj = obj or {}
  obj.string = str
  obj.getchar = str:gmatch(".")
  return dumbxml.new(obj)
end

local parse_entity

-- parse attribute lists (a='b' c='d')
-- also works with (illegal in xml, but legal in html) a=b, and a forms (in the
-- latter case, value is a)
local function parse_attrs(obj, out)
  -- skip whitespaces
  local c = obj.current_char
  while true do
    if not obj.tag_whitespace[c] then break end
    c = obj.getchar()
  end

  if c == obj.tag_terminate or c == obj.tag_separator_end then
    obj.current_char = c
    return out
  end

  local name = {}
  while true do
    if c == obj.tag_eq or obj.tag_whitespace[c] or
       c == obj.tag_terminate or c == obj.tag_separator_end then break
    elseif c == nil then
      obj.current_char = c
      obj.error('EOS while parsing tag attribute list')
      return out
    end

    table.insert(name, c)
    c = obj.getchar()
  end
  name = table.concat(name)

  local value = name
  if c == obj.tag_eq then -- not a shorthand
    value = {}

    c = obj.getchar()
    if obj.tag_quote[c] then -- quoted string
      while true do
        local d = obj.getchar()
        if d == c then break
        elseif d == obj.entity_start then
          obj.current_char = d
          d = parse_entity(obj).value
        elseif d == nil then
          obj.current_char = d
          obj.error('EOS while parsing attribute value')
          return out
        end
        table.insert(value, d)
      end
      c = obj.getchar()
    else -- look until whitespace/tag end
      while true do
        if obj.tag_whitespace[c] or c == obj.tag_terminate or
          c == obj.tag_separator_end then break
        elseif c == obj.entity_start then
          obj.current_char = c
          c = parse_entity(obj).value
        elseif c == nil then
          obj.current_char = c
          obj.error('EOS while parsing attribute value')
          return out
        end
        table.insert(value, c)
        c = obj.getchar()
      end
    end
    value = table.concat(value)
  end
  out[name] = value
  obj.current_char = c
  return parse_attrs(obj, out)
end

-- parse tags like <foo>, </bar> <x y="z" />, and so on
local function parse_tag(obj)
  local type = dumbxml.START_TAG
  local c = obj.getchar()
  if c == obj.tag_terminate then
    type = dumbxml.END_TAG
    c = obj.getchar()
  end

  local name = {}
  while true do
    if c == obj.tag_separator_end then break
    elseif c == obj.tag_terminate then break
    elseif obj.tag_whitespace[c] then break
    elseif c == nil then
      obj.current_char = c
      obj.error('EOS while parsing tag')
      break
    end

    table.insert(name, c)
    c = obj.getchar()
  end
  name = table.concat(name)

  obj.current_char = c
  attrs = parse_attrs(obj, {})

  c = obj.current_char
  obj.current_char = nil

  if c == obj.tag_terminate then
    obj.next_tag = { type = dumbxml.END_TAG, name = name }
    c = obj.getchar()
    if c ~= obj.tag_separator_end then
      obj.current_char = c
      obj.error("expected '"..obj.tag_separator_end.."', got '"..tostring(c).."'")
    end
  end

  return { type = type, name = name, attrs = attrs }
end

-- parse entities ( &name; ), find their values
parse_entity = function(obj)
  local name = {}
  while true do
    local c = obj.getchar()

    if c == obj.entity_end then break
    elseif c == nil then
      obj.current_char = c
      obj.error('EOS while parsing entity')
      break
    end
    table.insert(name, c)
  end
  name = table.concat(name)
  obj.current_char = nil

  local value = obj.entities[name] or obj:unknown_entity(name)
  return { type = dumbxml.ENTITY, name = name, value = value }
end

-- parse text nodes (stuff outside tags)
local function parse_text(obj)
  local text = {}
  local c = obj.current_char

  while true do
    if c == obj.entity_start then
      if obj.entity_replace then
        c = parse_entity(obj).value
      else
        break
      end
    elseif c == obj.tag_separator_start or c == nil then
      break
    end

    table.insert(text, c)
    c = obj.getchar()
  end
  obj.current_char = c

  return { type = dumbxml.TEXT, text = table.concat(text) }
end

function dumbxml:next()
  if self.next_tag then
    local t = self.next_tag
    self.next_tag = nil
    return t
  end

  self.current_char = self.current_char or self.getchar()
  local c = self.current_char
  if c == nil then
    return
  elseif c == self.tag_separator_start then
    return parse_tag(self)
  elseif not self.entity_replace and c == self.entity_start then
    return parse_entity(self)
  else
    return parse_text(self)
  end
end

function dumbxml:iter()
  return self.next, self
end

-- MTA (Multi Theft Auto, http://mtasa.com/) specific code begin
-- you can delete it if you do not want to use this in MTA
local function check_mta()
  -- export as a global name, since require is disabled...
  if getVersion().mta then
    _G.dumbxml = dumbxml
  end
end
pcall(check_mta)
-- end of MTA specific code

return dumbxml
