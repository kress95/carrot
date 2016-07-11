require 'lisp.lex'
require 'lisp.parse'
require 'lisp.build'

print(lisp.build(lisp.parse(lisp.lex("(* 4 (+ 1 (+ 2 3)))"), true), true).source)

