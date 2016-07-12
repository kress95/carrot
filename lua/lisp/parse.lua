if lisp == nil then
  lisp = {}
end

-------------------------------------------------------------------------------
-- macro handling
-------------------------------------------------------------------------------

lisp.macros = {}

function op(symbol, arity, dynamic)
  lisp.macros[symbol] = {
    type  = 'operator',
    arity = arity,
    name  = symbol
  }
end

function macro(symbol, arity)
  lisp.macros[symbol] = {
    type  = 'macro',
    arity = arity,
    name  = symbol
  }
end

function alias(symbol, source)
  lisp.macros[symbol] = lisp.macros[source]
end

-------------------------------------------------------------------------------
-- default macro set
-------------------------------------------------------------------------------

-- logic operators
op('and', 2)
op('or',  2)
op('not', 1)

alias('&&', 'and')
alias('||', 'or')
alias('~',  'not')

-- bitwise operators
macro('AND',    2)
macro('OR',     2)
macro('NOT',    1)
macro('XOR',    2)
macro('RSHIFT', 2)
macro('LSHIFT', 2)

alias('&:',  'AND')
alias('|:',  'OR')
alias('~:',  'NOT')
alias('^:',  'XOR')
alias('>>:', 'RSHIFT')
alias('<<:', 'LSHIFT')

-- comparison operators
op('=',  2) -- is equal
op('~=', 2) -- is not equal
op('>',  2) -- greater than
op('<',  2) -- lesser than
op('>=', 2) -- greater or equal to
op('<=', 2) -- lesser or equal to

-- miscelaneous macros
macro('++', 0) -- merge n tables
macro('--', 0) -- merge n strings
macro('?',  2) -- do block B when A is not nil, assigns 'it' to A
macro('!',  2) -- returns first value that is not nil
macro('#',  1) -- length operator
macro('%%', 2) -- modulo
macro('.',  2) -- partial application
macro('|>', 0) -- pipe operator

-- numeric operators
op('+',  2) -- addition
op('-',  2) -- subtraction
op('/',  2) -- division
op('*',  2) -- multiplication
op('^',  2) -- power
op('%',  2) -- remainder

-- core macros definition
macro('def', 2) -- define local value
macro('fun', 3) -- named function definition
macro('let', 0) -- lexical definition
macro('do',  2) -- anonymous function definition

alias('\\', 'do')

-- module system
macro('export',  2) -- exports B as A and export A as A when B is lacking
macro('import',  2) -- imports file A as B
macro('include', 2) -- includes A from B as a local
macro('global',  2) -- like def, but defines a global value, pls never use it

-- statements
macro('if',      2) -- do B when A is truthy
macro('but',     2) -- do B when A is falsy
macro('if-else', 2) -- do B when A is truthy and C when A is falsy
macro('cond',    2) -- does the first truthy tuple

-- lisp.parse, the parser
function lisp.parse(lexres, debug)
  if debug == nil then
    debug = true
  end

  if lexres.result.error then
    return {
      ast    = {},
      result = lexres.result
    }
  end

  local output = {
    ast = {
      type  = 'root',
      value = {},
    },
    result = {
      error   = false,
      message = ''
    }
  }

  local scopes = { output.ast }
  local heredoc_depth = 0

  function push_scope(scope)
    table.insert(scopes, scope)
  end

  function pop_scope()
    table.remove(scopes)
  end

  function err(message, token)
    -- set skip mode
    output.ast = {}
    output.result.error = true
    output.result.message = message .. ' (At ' .. token.position .. ')'
  end

  for idx = 1, #lexres.tokens do

    if output.result.error then
      break
    end

    local token = lexres.tokens[idx]

    -- last type
    local last_scope = scopes[table.maxn(scopes)]

    -- define mode
    local mode = 'literal'

    if token.type == 'heredoc' and token.value == 'begin' then
      mode = 'heredoc'
    elseif token.type == 'paren' and token.value == 'begin' then
      mode = 'call'
    elseif token.type == 'square' and token.value == 'begin' then
      mode = 'list'
    elseif token.type == 'curly' and token.value == 'begin' then
      mode = 'table'
    elseif (token.type == 'heredoc' or
            token.type == 'paren' or
            token.type == 'square' or
            token.type == 'curly') and
            token.value == 'end' then
      mode = 'close'
    end

    if mode == 'heredoc' or
       mode == 'call' or
       mode == 'list' or
       mode == 'table' then

      local build = {
        type  = mode,
        value = {}
      }

      table.insert(last_scope.value, build)
      push_scope(build)

    elseif mode == 'close' then
      if last_scope.type == 'call' and last_scope.name == nil then
        last_scope.type = 'block'
        last_scope.value[#last_scope.value] = {
          type  = 'return',
          value = last_scope.value[#last_scope.value]
        }
      end
      pop_scope()
    elseif mode == 'literal' then
      if last_scope.type == 'call' or
         last_scope.type == 'macro' or
         last_scope.type == 'operator' then

        local args = table.maxn(last_scope.value)

        if args == 0 and
           last_scope.name == nil then

          if token.type ~= 'literal' then
            last_scope.type = token.type
            last_scope.value = token.value
          else
            local data = lisp.macros[token.value]

            if data ~= nil then
              last_scope.type  = data.type
              last_scope.arity = data.arity
              last_scope.name  = data.name
            else
              last_scope.name     = token.value
            end

            last_scope.position = token.position
          end
        else
          if last_scope.arity == nil or
             last_scope.arity == 0 or
             last_scope.arity > args then
            table.insert(last_scope.value, token)
          else
            err(
              'Wrong number of arguments for macro [' .. last_scope.name ..
              '], expected ' .. last_scope.arity .. ' but got ' .. args + 1 ..
              '.', token)
          end
        end
      elseif last_scope.type == 'list' or
             last_scope.type == 'table' or
             last_scope.type == 'root' then
        table.insert(last_scope.value, token)
      else
        err('Cannot call a [' .. last_scope.type .. '].', token)
      end
    end
  end

  return output
end
