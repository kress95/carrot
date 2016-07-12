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
      message .. '(at ' .. token.position .. ')'
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

  -- separator delimiter
  function delim_separe(list, l, r, s)
    local output = {}
    local length = #list

    table.insert(output, tk(l))

    for idx=1, length do
      table.insert(output, list[idx])
      if idx < length then
          table.insert(output, tk(s))
      end
    end

    table.insert(output, tk(r))

    return output
  end

  -- list delimiter
  function delim_list(list)
    return delim_separe(list, '{\n', '}', ',\n')
  end

  -- arguments delimiter
  function delim_args(list)
    return delim_separe(list, '(', ')', ', ')
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
        table.insert(output, tk(',\n'))
      end
    end

    table.insert(output, tk('\n}'))
  end

  -----------------------------------------------------------------------------
  -- native macros
  -----------------------------------------------------------------------------

  local macro = {}

  -- (def name value) -> local name = value
  function macro.def(token, args)
    if args[1].type ~= 'literal' then
      return err(
        args[1],
        'Cannot define a [' .. args[1].type .. '] to a value.'
      )
    end

    return { tk('local '), args[1], tk('=', 'operator'), args[2], tk('\n') }
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

  function analyze(token, args)
    if token.type == 'macro' then
      return macro[token.name](token, args)
    elseif token.type == 'operator' then
      return delim_math({
        args[1],
        strip(token),
        args[2]
      })
    elseif token.type == 'call' then
      return {
        strip(token),
        delim_args(args)
      }
    elseif token.type == 'root' then
      return args
    else
      -- unknown token type, dunno what to do, will just return
      return token
    end

    return token
  end

  -----------------------------------------------------------------------------
  -- token traversal
  -----------------------------------------------------------------------------

  function traverse(token)
    if type(token) == 'table' then
      if token.value == nil and type(token) == 'table' then
        -- this code does usually doesn't need any changes,
        -- it's here to support form lists
        local map = {}

        for k,v in pairs(token) do
          map[k] = traverse(v)
        end

        return map
      elseif type(token.value) == 'table' then
        -- let's analyze the token values and analyze them
        return analyze(token, traverse(token.value))

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

  local iterable = flatten(codegen_tree)

  for idx=1, #iterable do
    local token = iterable[idx]
    if token.type == 'string-a' then
      write(token, "'" .. token.value .. "'")
    elseif token.type == 'string-b' then
      write(token, '"' .. token.value .. '"')
    elseif token.type == 'operator' then
      write(token, ' ' .. token.value .. ' ')
    else
      write(token, token.value)
    end
  end

  -- return output
  return output
end


--[[
-- local functions object
local _ = {}

-- raw token
function _.raw(symbol, position)
  if position == nil then
    position = ''
  end
  return {
    type     = 'raw',
    value    = symbol,
    position = position
  }
end

-- mutable merge
function _.mut_merge(...)
  local args = { ... }
  local first = args[1]
  local length = #args

  if length > 1 then
    for idx = 2, #args do
      local c_arg = args[idx]
      for k,v in pairs(c_arg) do
        table.insert(first, v)
      end
    end
  end

  return first
end

-- round value with parens when needed
function _.parens(value)
  if value.type ~= nil then
    return { value }
  else
    return _.mut_merge({ _.raw('(') }, value, { _.raw(')') })
  end
end

-- monadic maths
function _.monadic_math(op, a)
  return _.parens(_.mut_merge({ op }, { a }))
end

-- dyadic maths
function _.dyadic_math(a, op, b)
  return _.mut_merge(_.parens(a), { op }, _.parens(b))
end

-- operator
function _.operator(tk)
  local name  = tk.name
  local arity = lisp.macros_arity[name]
  if arity == 2 then
    local op = _.raw(' ' .. name .. ' ', tk.position)
    return _.dyadic_math(tk.value[1], op, tk.value[2])
  elseif arity == 1 then
    local op = _.raw(name .. ' ', tk.position)
    return _.monadic_math(op, tk.value[1])
  end
end


-- default macros
local macros = {
  ['+']  = 'op',
  ['-']  = 'op',
  ['/']  = 'op',
  ['*']  = 'op',
  ['^']  = 'op'
}

-- def macro
function macros.def(tk)
  local name  = tk.value[1]
  local value = {}

  for idx = 2, #tk.value do
    table.insert(value, tk.value[idx])
  end

  if #value == 1 then
    value = value[1]
  end

  return _.mut_merge(
    { _.raw('local ') },
    _.dyadic_math(
      name,
      _.raw(' = '),
      value
    ),
    { _.raw('\n') }
  )
end

-- let macro
function macros.let(tk)
  local output = {}

  local args   = {}
  local values = {}
  local length = #tk.value - 1

  for idx=1, length do
    if idx % 2 == 0 then
      if #values > 0 then
        table.insert(values, _.raw(', '))
      end
      _.mut_merge(values, _.parens(tk.value[idx]))
    else
      if #args > 0 then
        table.insert(args, _.raw(', '))
      end
      table.insert(args, tk.value[idx])
    end
  end

  table.print(tk)

  return _.mut_merge(
    { _.raw('(function(') }, args, { _.raw(')\n') },
    tk.value[length + 1], { _.raw('\nend)') },
    { _.raw('(') }, values, { _.raw(')\n') }
  )
end


-- lisp.build, the builder
function lisp.build(parseres, debug)
  if debug == nil then
    debug = true
  end

  if parseres.result.error then
    return {
      source = '',
      result = parseres.result
    }
  end

  local stack  = {}

  function merge(a, b)
    if type(b) == 'table' and b[1] ~= nil then
      for k,v in pairs(b) do table.insert(a, v) end
    else
      table.insert(a, b)
    end
  end

  function map(a, fn)
    local b = {}
    for idx = 1, #a do
      b[idx] = fn(a[idx])
    end
    return b
  end

  function analyze(curr)
    local ast = {}

    if curr.type == 'root' then
      table.insert(ast, {
        type     = 'comment',
        value    = ' Generated by LuaS2Lisp@0.0.1 :3',
        position = '0:0'
      })

      map(curr.value, function(item) merge(ast, analyze(item)) end)
      return ast
    elseif curr.type == 'macro' then
      curr.value = map(curr.value, function(item)
        return analyze(item)
      end)


      local guide = macros[curr.name]

      if guide == 'op' then
        return _.mut_merge(ast, _.operator(curr))
      elseif type(guide) == 'function' then
        return _.mut_merge(ast, guide(curr))
      end

      return ast
    elseif curr.type == 'block' then
      map(curr.value, function(item)
        _.mut_merge(ast, analyze(item))
      end)

      return ast
    elseif curr.type == 'return' then
      _.mut_merge(
        ast,
        { _.raw('return ') },
        analyze(curr.value)
      )

      return  ast
    else
      return curr
    end
  end

  local output = {
    source = '',
    result = {
      error   = false,
      message = ''
    }
  }

  function line(str)
    output.source = output.source .. str .. '\n'
  end

  function raw(str)
    output.source = output.source .. str
  end


  local flat_tokens = analyze(parseres.ast)

  for idx = 1, #flat_tokens do
    local token = flat_tokens[idx]

    if token.type == 'comment' then
      line('--' .. token.value)
    elseif token.type == 'raw' or
           token.type == 'number' or
           token.type == 'literal' then
      raw(token.value)
    elseif token.type == 'astr' then
      raw("'" .. token.value .. "'")
    elseif token.type == 'bstr' then
      raw('"' .. token.value .. '"')
    end
  end

  return output
end
]]
