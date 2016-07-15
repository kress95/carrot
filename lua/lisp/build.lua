--[[
Remaining macros:

-- complex operators
macro('cond',    2) -- does the first truthy tuple
macro('?',  2)      -- do block B when A is not nil, assigns 'it' to A

-- dynamic operators
macro('++', 0) -- merge n tables
macro('--', 0) -- merge n strings

-- unplanned operators
macro('|>', 0) -- pipe operator
macro('$',  2) -- partial application
macro('!',  2)      -- returns first value that is not nil

]]

if lisp == nil then
  lisp = {}
end

require 'lisp.parse'

-------------------------------------------------------------------------------
-- macro handling
-------------------------------------------------------------------------------


function lisp.build(parseres, debug)
  -- pass previous erros forward
  if parseres.result.error then
    return {
      source  = '',
      mapping = {},
      result  = { parseres.result }
    }
  end

  -- debug is true by default
  if debug == nil then
    debug = true
  end

  -- output value
  local output = {
    source  = '',
    mapping = {},
    result  = {
      error   = false,
      message = { }
    }
  }

  -- write string to output, maps to token
  function write(token, str)
    output.source = output.source .. str
  end

  -- write error to output
  function err(token, message)
    output.result.error = true
    table.insert(
      output.result.message,
      message .. ' (at ' .. token.position .. ')'
    )
    return { }
  end

  -----------------------------------------------------------------------------
  -- token managers
  -----------------------------------------------------------------------------

  -- build token of given type (default: plain)
  function tk(value, type)
    if type == nil then
      type = 'plain'
    end
    return {
      type     = type,
      value    = value,
      position = ''
    }
  end

  -- identation
  function nl()
    return {
      type     = 'newline',
      value    = '',
      position = ''
    }
  end


  -- identation
  function ident(value)
    return {
      type     = 'ident',
      value    = value,
      position = ''
    }
  end

  -- turn token name into value, stripping arguments off
  function strip(token)
    return {
      type     = token.type,
      value    = token.name,
      position = token.position
    }
  end

  -----------------------------------------------------------------------------
  -- token delimiters
  -----------------------------------------------------------------------------

  -- math delimiter
  function delim_math(list)
    return { tk('('), list, tk(')') }
  end

  -- separator
  function separe(list, s)
    local output = {}
    local length = #list

    for idx=1, length do
      table.insert(output, list[idx])
      if idx < length then
          table.insert(output, s)
      end
    end

    return output
  end

  -- separator delimiter
  function delim_separe(list, l, r, s)
    local output = {}
    local length = #list

    table.insert(output, l)

    for idx=1, length do
      table.insert(output, list[idx])
      if idx < length then
          table.insert(output, s)
      end
    end

    table.insert(output, r)

    return output
  end

  -- list delimiter
  function delim_list(list)
    return delim_separe(
      list,
      { tk('{'), ident(1) },
      { ident(-1), nl(), tk('}') },
      { nl(), tk(',') })
  end

  -- arguments delimiter
  function delim_args(list)
    return delim_separe(list, tk('('), tk(')'), tk(', '))
  end

  -- map delimiter
  function delim_map(list)
    local output = {}
    local length = #list / 2

    table.insert(output, tk('{\n'))

    for idx=1, length do
      key = list[idx * 2]
      val = list[(idx * 2) + 1]
      table.insert(output, key)
      table.insert(output, tk('=', 'operator'))
      table.insert(output, val)
      if idx < length then
        table.insert(output, { tk(','), nl()})
      end
    end

    table.insert(output, tk('\n}'))
  end

  -- converts args into a neoblock when A is not a block
  function neoblock(a, args)
    if args[a].type ~= 'block' then
      local block = {}

      for idx=a, #args do
        table.insert(block, args[idx])
      end

      return traverse({
        type  = 'neoblock',
        value = block,
        position = ''
      })
    else
      return traverse(args[a])
    end
  end

  function orblock(token)
    if token.type == 'block' then
      return token
    else
      return {
        type     = 'block',
        position = '',
        value    = {
          type     = 'return',
          position = '',
          value    = token
        }
      }
    end
  end

  -----------------------------------------------------------------------------
  -- native macros
  -----------------------------------------------------------------------------

  local macros = {}

  -- (let name value ... block) -> (function(name) return block end)(value)
  function macros.let(token, last)
    local args   = token.value
    local length = (#args - 1) / 2
    local block  = args[#args]

    local names  = {}
    local values = {}

    if length % 2 ~= 1 then
      return err(token,
        '[let] wrongly used, please use a key-value pattern ' ..
        'with the last param being a block.')
    end

    for idx=1, length do
      local key = args[(((idx - 1) * 2) + 1)]

      if key.type ~= 'literal' then
        return err(key,
        'Cannot define a [' .. key.type .. '] to a value.')
      end


      table.insert(names, key)
      table.insert(values, args[(((idx - 1) * 2) + 2)])
    end

    return {
      tk('(function'),
      traverse(delim_args(names)),
      ident(1),
      nl(),
      traverse(orblock(block)),
      ident(-1),
      nl(),
      tk('end)'),
      traverse(delim_args(values))
    }
  end

  -- (def name value) -> local name = value
  function macros.def(token, last)
    local args = traverse(token.value)

    if args[1].type ~= 'literal' then
      return err(
        args[1],
        'Cannot define a [' .. args[1].type .. '] to a value.'
      )
    end

    if last then
      return { args[2] }
    else
      return { tk('local '), args[1], tk('=', 'operator'), args[2] }
    end
  end

  -- (global name value) -> name = value
  function macros.global(token, last)
    local args = traverse(token.value)

    if args[1].type ~= 'literal' then
      return err(
        args[1],
        'Cannot define a [' .. args[1].type .. '] to a value.'
      )
    end

    return { args[1], tk('=', 'operator'), args[2] }
  end

  -- (fun name [args] (block)) -> function name(args) block end
  function macros.fun(token, last)
    local args = token.value

    if args[1].type ~= 'literal' then
      return err(
        args[1],
        'Cannot define a function with a [' .. args[1].type .. '] name.'
      )
    end

    if args[2].type ~= 'list' then
      return err(args[2], 'Arguments list must be of [list] type.')
    else
      args[2] = traverse(args[2])
    end

    if last then
      return {
        tk('function'),
        delim_args(args[2].value),
        nl(),
        neoblock(3, args),
        nl(),
        tk('end')
      }
    else
      return {
        tk('function '),
        args[1],
        delim_args(args[2].value),
        ident(1),
        nl(),
        neoblock(3, args),
        ident(-1),
        nl(),
        tk('end')
      }
    end
  end

  -- (do [args] (block)) -> function(args) block end
  macros['do'] = function (token, last)
    local args = token.value

    if args[1].type ~= 'list' then
      return err(args[1], 'Arguments list must be of [list] type.')
    else
      args[1] = traverse(args[1])
    end

    return {
      tk('function'),
      delim_args(args[1].value),
      nl(),
      neoblock(2, args),
      nl(),
      tk('end')
    }
  end

  -- if expression
  macros['if'] = function (token, last)
    local args = token.value
    return {
      tk('(function()'),
      ident(1),
      nl(),
      tk('if '), traverse(args[1]), tk(' then'),
      ident(1),
      nl(),
      neoblock(2, args),
      ident(-1),
      nl(),
      tk('end'),
      ident(-1),
      nl(),
      tk('end)()')
    }
  end

  -- if expression
  macros['if-else'] = function (token, last)
    local args = token.value
    return {
      tk('(function()'),
      ident(1),
      nl(),
      tk('if '), traverse(args[1]), tk(' then'),
      ident(1),
      nl(),
      traverse(orblock(args[2])),
      ident(-1),
      nl(),
      tk('else'),
      ident(1),
      nl(),
      traverse(orblock(args[3])),
      ident(-1),
      nl(),
      tk('end'),
      ident(-1),
      nl(),
      tk('end)()')
    }
  end

  -- but expression, does action only when falsy
  macros['but'] = function (token, last)
    local args = token.value
    return {
      tk('(function()'),
      ident(1),
      nl(),
      tk('if not '), traverse(args[1]), tk(' then'),
      ident(1),
      nl(),
      neoblock(2, args),
      ident(-1),
      nl(),
      tk('end'),
      ident(-1),
      nl(),
      tk('end)()')
    }
  end

  -- true remainder
  macros['%%'] = function (token, last)
    local args = token.value
    local a = traverse(args[1])
    local b = traverse(args[2])
    return {
      tk('('),
      tk('('),
      a,
      tk('%', 'operator'),
      b,
      tk(')'),
      tk('+', 'operator'),
      b,
      tk(')'),
      tk('%', 'operator'),
      b
    }
  end

  -- length operator
  macros['#'] = function (token, last)
    if token.value[1].type ~= 'literal' then
      return err(
        token.value[1],
        'Cannot inspect length of non [literal] values.'
      )
    end
    return {
      tk('#'),
      token.value[1]
    }
  end

  macros['AND'] = function (token, last)
    return {
      tk('bit.band'),
      delim_args({traverse(token.value[1]), traverse(token.value[2])})
    }
  end

  macros['OR'] = function (token, last)
    return {
      tk('bit.bor'),
      delim_args({traverse(token.value[1]), traverse(token.value[2])})
    }
  end

  macros['NOT'] = function (token, last)
    return {
      tk('bit.bnot'),
      delim_args({traverse(token.value[1])})
    }
  end

  macros['XOR'] = function (token, last)
    return {
      tk('bit.bxor'),
      delim_args({traverse(token.value[1]), traverse(token.value[2])})
    }
  end

  macros['LSHIFT'] = function (token, last)
    return {
      tk('bit.lshift'),
      delim_args({traverse(token.value[1]), traverse(token.value[2])})
    }
  end

  macros['RSHIFT'] = function (token, last)
    return {
      tk('bit.rshift'),
      delim_args({traverse(token.value[1]), traverse(token.value[2])})
    }
  end

  -----------------------------------------------------------------------------
  -- flatten list
  -----------------------------------------------------------------------------

  function flatten(list)
    local output = {}

    for idx=1, #list do
      local item = list[idx]

      if type(item) == 'table' and item[1] ~= nil then
        local concat = flatten(item)
        for idx=1, #concat do
          table.insert(output, concat[idx])
        end
      else
        table.insert(output, item)
      end
    end

    return output
  end

  -----------------------------------------------------------------------------
  -- token analysis
  -----------------------------------------------------------------------------

  function analyze(token, last)
    if token.type == 'macro' then
      local macro = macros[token.name]
      if macro == nil then
        return err(token, 'Macro [' .. token.name .. '] is not defined.')
      else
        return macro(token, last)
      end
    elseif token.type == 'neoblock' then
      local separed = separe(token.value, nl())
      local value   = {}
      local length  = #separed

      for idx=1, length do
        if idx < length then
          value[idx] = analyze(separed[idx], false)
        else
          value[idx] = tk('return ')
          table.insert(value, analyze(separed[idx], true))
        end
      end

      return value
    else
      local value = traverse(token.value, last)

      if token.type == 'operator' then
        local a = value[1]
        local b = value[2]

        if a[1] ~= nil and token.value[1].type ~= 'call' then
          a = delim_math(a)
        end

        if b[1] ~= nil and token.value[2].type ~= 'call' then
          b = delim_math(b)
        end

        return { a, strip(token), b }
      elseif token.type == 'call' then
        return {
          strip(token),
          delim_args(value)
        }
      elseif token.type == 'return' then
        return {
          tk('return '),
          traverse(token.value, true)
        }
      elseif token.type == 'root' or token.type == 'block' then
        if type(token.value) == 'table' and token.value[1] ~= nil then
          return separe(value, nl())
        else
          return value
        end
      else
        return token -- list and tables
      end
    end
  end

  -----------------------------------------------------------------------------
  -- token traversal
  -----------------------------------------------------------------------------

  function traverse(token, last)
    if last == nil then
      last = false
    end

    if type(token) == 'table' then
      if token.value == nil and type(token) == 'table' then
        -- this code does usually doesn't need any changes,
        -- it's here to support form lists
        local map = {}

        for k,v in pairs(token) do
          map[k] = traverse(v, last)
        end

        return map
      elseif type(token.value) == 'table' then
        -- let's analyze the token values and analyze them
        return analyze(token, last)

      else
        -- flat tokens, we just return them most of time
        return token
      end
    else
      -- reaching here is usually error, but I don't care
      return token
    end
  end

  -----------------------------------------------------------------------------
  -- build output string
  -----------------------------------------------------------------------------
  local codegen_tree = traverse(parseres.ast)

  if output.result.error then
    output.source = ''
    return output
  end

  local iterable   = flatten(codegen_tree)
  local identation = 0

  for idx=1, #iterable do
    local token = iterable[idx]

    if token.type == 'string-a' then
      write(token, "'" .. token.value .. "'")
    elseif token.type == 'string-b' then
      write(token, '"' .. token.value .. '"')
    elseif token.type == 'operator' then
      write(token, ' ' .. token.value .. ' ')
    elseif token.type == 'comment' then
      write(token, '--' .. token.value)
    elseif token.type == 'newline' then
      output.source = output.source .. '\n'

      for idx2=1, identation do
        output.source = output.source .. '    '
      end
    elseif token.type == 'ident' then
      identation = identation + token.value
    elseif token.type == 'boolean' or
           token.type == 'nil' or
           token.type == 'number' then
      write(token, token.value)
    elseif token.type ~= nil then
      if type(token.value) == 'table' then
        table.print(token)
      end
      write(token, token.value)
    end
  end

  -- return output
  return output
end
