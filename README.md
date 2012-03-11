dumbxml
=======

Simple parser written in Lua, that can parse a little subset of XML. You can
parse simple XML/HTML based formats, like [Pango Markup][pangomarkup]. You only
get a tag-soup, a list of parser events, like in SAX, it won't produce a DOM.

It can parse: start/end tags, empty element tags (`<foo />`), attributes
(including HTML "features", like omitting quotes and attribute minimization),
entities. You can redefine every special XML character, can use your custom
entity set, and you can tell the parser to ignore any errors.

It doesn't do any validating, it will parse non well-formed documents, and
doesn't support any fancy features, like DTD or CDATA.

Usage
=====

Place `dumbxml.lua` somewhere require can find it.

    local dumbxml = require('dumbxml')

After this, you can create new parser instances using `dumbxml.new(tbl)`. You
have to pass a table, which at least contains a `getchar` key, which is a
function that returns one new character (as a lua string) each time called. You
can use `dumbxml.fromString(string, optional tbl)` as a shortcut when you want
to parse a single string.

Other keys you can specify:

 * `entities`: the set of entities supported as key-value pairs. Note that it
   will replace the default set of entities, you must also specify them if you
   want them.
 * `unknown_entity`: `function(object, entity)` called when an unknown entity is
   read. By default, it produces an error. If your function returns, it must
   return a string containing the replacement text.
 * `entity_replace`: when true, entities are replaced with their values in text
   nodes, otherwise entity nodes are also produced. By default, it's true.
 * `error`: called when an error occurs. By default, it's the same as lua's
   `error`. If you specify it as `function() end`, it will silently ignore all
   errors.
 * xml character sets: you can redefine characters used by xml. These take a
   single character: `tag_separator_start` (`<`), `tag_separator_end` (`>`),
   `tag_terminate` (`/`), `tag_eq` (`=`), `entity_start` (`&`), `entity_end`
   (`;`). The following two take a multi-character string: `tag_whitespace`
   (` \t\r\n`), `tag_quote` (`'"`).

After this, you can call `next()` on the instance to get the next node, or nil
if you reached the end of the document. Or you can call `iter()`, and you
receive an iterator.

The table key `type` contains the node type. Possible values:

 * `dumbxml.START_TAG` (or `dumbxml.START_ELEMENT`): a start tag. `name`
   contains the tag name, and `attrs` the attribute pairs.
 * `dumbxml.END_TAG` (or `dumbxml.END_TAG`): an end tag. `name` contains the tag
   name. Empty tags generate a start/end pair.
 * `dumbxml.TEXT`: text node. `text` contains the text.
 * `dumbxml.ENTITY`: an entity reference. `name` is the reference (the suff
   between `&` and `;`), `value` is the entity value. Only when `entity_replace`
   is false.

You can check `test.lua` for some usage examples (and a unittest!). Use
[shake][shake] to run it, or just `lua test.lua` if you do not want to install
shake. Although error messages will be less useful...

License
=======

Copyright 2012 by Kővágó, Zoltán

This program is free software. It comes without any warranty, to the extent
permitted by applicable law. You can redistribute it and/or modify it under the
terms of the Do What The Fuck You Want To Public License, Version 2, as
published by Sam Hocevar. See http://sam.zoy.org/wtfpl/COPYING for more details.


[pangomarkup]: http://developer.gnome.org/pango/stable/PangoMarkupFormat.html
[shake]: http://shake.luaforge.net/
