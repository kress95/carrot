--[[


]]
if lisp == nil then
  lisp = {}
end

require 'lisp.lex'
require 'lisp.parse'
require 'lisp.build'

function lisp.compile(str, debug)
  if debug == nil then
    debug = false
  end
  return lisp.build(lisp.parse(lisp.lex(str), debug), debug)
end
