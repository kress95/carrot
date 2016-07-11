--
require 'lisp.lex'
require 'lisp.parse'
require 'lisp.build'
--require 'lisp.gen'

lisp.lex('(+ 1 1)')
--print(gen(parse(lex("(+ 1 (+ 2 3))"))))
--print(gen(parse(lex("(+ 1 (+ 2 3))"))))

