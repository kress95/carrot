require 'lisp.lex'
require 'lisp.parse'
require 'lisp.build'

local script =
  lisp.build(
    lisp.parse(
      lisp.lex("\
; olar mundo\
(def d (let a 10 b 20 (\
  (def c (+ a b))\
  (* c b))))"),
      true
    ),
  true).source
print(script)


