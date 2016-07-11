if lisp == nil then
  lisp = {}
end

-- operators arity
lisp.macros_arity = {
  -- logic operators
  ['~~'] = 1, -- not operator
  ['&&'] = 2, -- and operator
  ['||'] = 2, -- or operator

  -- bitwise operators
  ['&:']  = 2, -- bitwise AND
  ['|:']  = 2, -- bitwise OR
  ['~:']  = 1, -- bitwise NOT
  ['^:']  = 2, -- bitwise XOR
  ['<<:'] = 2, -- bitwise LSHIFT
  ['>>:'] = 2, -- bitwise RSHIFT

  -- comparison operators
  ['=']  = 2, -- is equal?
  ['!='] = 2, -- is not equal?
  ['>']  = 2, -- is greater than?
  ['<']  = 2, -- is lesser than?
  ['>='] = 2, -- is equal or greater than?
  ['<='] = 2, -- is equal or lesser than?

  -- misc operators
  ['++'] = 2, -- table merge
  ['--'] = 2, -- string concatenation
  ['?']  = 2, -- do block when value is not nil, `it = value`
  ['$']  = 1, -- length operator

  -- numeric operators
  ['+']  = 2, -- addition
  ['-']  = 2, -- subtraction
  ['/']  = 2, -- division
  ['*']  = 2, -- multiplication
  ['^']  = 2, -- power
  ['%']  = 2, -- remainder
  ['%%'] = 2, -- modulo

  -- fixed arity macros
  ['fun'] = 3, -- define named function
  ['def'] = 2, -- define local value
  ['var'] = 2, -- define global value
  ['\\']  = 2, -- define anonymous function
  ['if']  = 2, -- if statement as a expression
  ['but'] = 2, -- unless statement as a expression
  ['but'] = 2, -- unless statement as a expression

  -- variadic macros
  ['!']   = 0, -- returns first value that is not nil
  ['.']   = 0, -- partial application
  ['let'] = 0, -- lexical definition
  ['|>']  = 0  -- pipe operator
}

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
         last_scope.type == 'macro' then

        local args = table.maxn(last_scope.value)

        if args == 0 and
           last_scope.name == nil then

          if token.type ~= 'literal' then
            last_scope.type = token.type
            last_scope.value = token.value
          else
            local arity = lisp.macros_arity[token.value]

            if arity ~= nil then
              last_scope.type  = 'macro'
              last_scope.arity = arity
            end

            last_scope.name     = token.value
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
