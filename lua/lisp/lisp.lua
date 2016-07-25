require 'lisp.lex'
require 'lisp.parse'
require 'lisp.build'

local filename = arg[1]
local source

if filename ~= '' then
  local file     = assert(io.open(filename, 'r'))
  source   = file:read('*all')

  file:close()
else
  source = ''
end

local clean = false

if #arg >= 2 then
  clean = arg[2] == 'clean'
end

local results = lisp.build(lisp.parse(lisp.lex(source)), true, clean)

if results.result.error then
  warn('-----------')
  table.print(results.result.message)
  os.exit(-1)
else
  print(results.source)
end
