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

  local macros = {}

  -- (def name value) -> local name = value
  function macros.def(token, args)
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
      local macro = macros[token.name]
      if macro == nil then
        return err(token, 'Macro [' .. token.name .. '] is not defined.')
      else
        return macro(token, args)
      end
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
