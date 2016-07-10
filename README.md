# Carrot

Carrot is a portable game engine made with luajit and sdl2.

It's development is made alongside with a farming game, after getting the game done, the carrot part will be extracted and maintained in a separate place.

## Dependencies

* LuaJIT-2.0.4
* SDL2-2.0.4
* SDL2_ttf-2.0.14
* SDL2_mixer-2.0.1
* SDL2_image-2.0.1
* lua-sdl2-ffi (enhanced and bundled)

## LuaLisp Cheatsheet

LuaLisp is a very simple lisp-like functional programming language
with no macro support.

It was made to be a stable way to get rid of lua's verbosiness,
not to get better meta programming methods.

Numbers, strings and booleans works the same way they work on lua.
Operators are optimized as they should.

    Lisp                     | Lua
    --------------------------------------------------------------
    ; rest of the line       | -- rest of the line
    [1 2 3 4 5 6 7]          | { 1, 2, 3, 4, 5, 6, 7 }
    { key 'value' }          | { key = 'value' }
    (let x y)                | local x = y
    (def x y)                | x = y
    (fun name (args) (body)) | function name(args) return body end
    (do (args) (body))       | function(args) return body end
    (lua 'a + b')            | a + b
    (not-a-macro 1 2 3)      | not_a_macro(1, 2, 3)

Most of the source will be done with LuaLisp.

Lualisp uses the `.lisp.lua` extension, and is compatible with clojure
syntax highlighting.

## License

Game License: GPLv3
Carrot License: Apache 2.0
