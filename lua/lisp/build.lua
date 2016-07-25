if lisp == nil then
  lisp = {}
end

require 'lisp.parse'

-------------------------------------------------------------------------------
-- macro handling
-------------------------------------------------------------------------------


function lisp.build(parseres, debug, clear)
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
    source  = [[
if __lisp_global_methods__ == nil then
  __mark_list__ = function (tbl)
    setmetatable(tbl, { __is_list__ = true })
    return tbl
  end

  __is_list__ = function (tbl)
    return getmetatable(tbl).__is_list__ ==  true
  end

  __merge_tables__ = function (...)
    local out  = { }
    local args = {...}

    for idx=1, #args do
      local curr = args[idx]

      for idx2=1, #curr do
        table.insert(out, curr[idx2])
      end
    end

    return out
  end

  __concat_str_list__ = function (...)
    local args = {...}
    local mode = false

    for idx=1, #args do
      if type(args[idx]) ~= 'string' then
        mode = true
        break
      end
    end

    if mode == false then
      local output = ''

      for idx=1, #args do
        output = output .. args[idx]
      end

      return output
    else
      local output = {}

      for idx=1, #args do
        local curr = args[idx]
        for idx2=1, #curr do
          table.insert(output, curr[idx2])
        end
      end

      return output
    end
  end

  __merge_tables__ = function (...)
    local out  = { }
    local args = ...

    for idx=1, #args do
      local curr = args[idx]

      for k,v in pairs(curr) do
        out[k] = v
      end
    end

    return out
  end

  function __option__ = function (...)
    local args = ...
    local out  = nil

    for idx=1, #args do
      local value = args[idx]
      if value ~= nil then
        out = value
      end
    end

    return out
  end

  __curry__ = function(func, ...)
    local info     = debug.getinfo(func, 'u')
    local isvararg = info.isvararg
    local nparams  = info.nparams
    local head     = { ... }

    if isvararg or #head >= nparams then
      return func(unpack(head))
    end

    return function(...)
      local tail = { ... }

      for idx=1, #tail do
        table.insert(head, tail[idx])
      end

      if #head >= nparams then
        return func(unpack(head))
      end

      return curry(func, unpack(head))
    end
  end

  __lisp_global_methods__ = true
end

]],
    mapping = {},
    result  = {
      error   = false,
      message = { }
    }
  }

  if clear == true then
    output.source = ''
  end

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

  function infer_operator(token)
    if type(token.value) == 'string' then
      local data = lisp.macro[token.value]

      if data == nil then
        return token
      end

      if data.type == 'operator' then
        if data.arity == 1 then
          return {
            tk('(function(x) return '),
            tk(data.name, 'operator'),
            tk('x'),
            tk(' end)')
          }
        elseif data.arity == 2 then
          return {
            tk('(function(y, x) return '),
            tk('x'),
            tk(data.name, 'operator'),
            tk('y'),
            tk(' end)')
          }
        end
      elseif data.type == 'macro' and (
             data.name == 'AND' or
             data.name == 'OR' or
             data.name == 'NOT' or
             data.name == 'XOR' or
             data.name == 'LSHIFT' or
             data.name == 'RSHIFT' or
             data.name == '%%') then

        local value

        if data.arity == 2 then
          value = {
            { position = '', type  = 'literal', value = 'x' },
            { position = '', type  = 'literal', value = 'y' }
          }
        else
          value = { { position = '', type  = 'literal', value = 'x' } }
        end

        local operation = traverse({
          position = '',
          type  = data.type,
          arity = data.arity,
          name  = data.name,
          value = value
        })

        if data.arity == 2 then
          return { tk('(function(y, x) return '), operation, tk(' end)') }
        else
          return { tk('(function(x) return '), operation, tk(' end)') }
        end
      end
    end

    return token
  end

  -----------------------------------------------------------------------------
  -- native macros
  -----------------------------------------------------------------------------

  local macros = {}

  -- (let name value ... block) -> (function(name) return block end)(value)
  function macros.let(token, last)
    if token.value[1].type ~= 'list' then
      return err(token.value[1], 'Arguments list must be of [list] type.')
    end

    local args  = token.value[1].value
    local block = neoblock(2, token.value)

    local length = #args / 2
    local names  = {}
    local values = {}

    if (length - 1) % 2 == 1 then
      return err(token,
        '[let] wrongly used, please use a key-value pattern ' ..
        'with the last param being a block.')
    end

    for idx=1, length do
      local base  = ((idx - 1) * 2) + 1
      local key   = args[base]
      local value = args[base + 1]

      if key.type ~= 'literal' then
        return err(key,
        'Cannot define a [' .. key.type .. '] to a value.')
      end

      table.insert(names,  key)
      table.insert(values, value)
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

    if args[1].type ~= nil and args[1].type ~= 'literal' then
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

    local name = traverse(args[1])

    if name.type ~= 'literal' then
      return err(
        args[1],
        'Cannot define a function with a [' .. args[1].type .. '] name.'
      )
    end

    if args[2].type ~= 'list' then
      return err(args[2], 'Arguments list must be of [list] type.')
    end

    if last then
      return {
        tk('function'),
        delim_args(args[2].value),
        nl(),
        traverse(neoblock(3, args)),
        nl(),
        tk('end')
      }
    else
      return {
        tk('function '),
        name,
        delim_args(args[2].value),
        ident(1),
        nl(),
        traverse(neoblock(3, args)),
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
    end

    return {
      tk('function'),
      delim_args(args[1].value),
      nl(),
      traverse(neoblock(2, args)),
      nl(),
      tk('end')
    }
  end

  -- (when test then...) -> eval(then) | nil
  macros['when'] = function (token, last)
    local args = token.value
    return {
      tk('(function()'),
      ident(1),
      nl(),
      tk('if '), traverse(args[1]), tk(' then'),
      ident(1),
      nl(),
      traverse(neoblock(2, args)),
      ident(-1),
      nl(),
      tk('end'),
      ident(-1),
      nl(),
      tk('end)()')
    }
  end

  -- but expression, does action only when falsy
  macros['when-not'] = function (token, last)
    local args = token.value
    return {
      tk('(function()'),
      ident(1),
      nl(),
      tk('if not '), traverse(args[1]), tk(' then'),
      ident(1),
      nl(),
      traverse(orblock(neoblock(2, args))),
      ident(-1),
      nl(),
      tk('end'),
      ident(-1),
      nl(),
      tk('end)()')
    }
  end

  -- (if test then else?) -> eval(then) | eval(else) | nil
  macros['if'] = function (token, last)
    local args   = token.value
    local length = #args

    if length == 2 then
      return macros['when'](token, last)
    elseif length ~= 3 then
      return err(
        'Wrong number of arguments for macro [' .. last_scope.name ..
        '], expected ' .. token.arity .. ' but got ' .. length .. '.',
        token
      )
    end

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

  -- get length
  macros['#'] = function (token, last)
    return {
      tk('#'),
      traverse(token.value)
    }
  end

  -- get length
  macros['at'] = function (token, last)
    return {
      traverse(token.value[2]),
      tk('['),
      traverse(token.value[1]),
      tk(']')
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

  macros['++'] = function (token, last)
    local args   = {}
    local length = #token.value
    local pure   = true


    for idx=1, length do
      local param = traverse(token.value[idx])

      table.insert(args, param)

      if param.type ~= 'string-a' and param.type ~= 'string-b' then
        pure = false
      end
    end

    if pure then
      local concat_list = {}
      for idx=1, length do
        table.insert(concat_list, traverse(args[idx]))
        if idx ~= length then
          table.insert(concat_list, tk('..', 'operator'))
        end
      end

      return delim_math(concat_list)
    else
      return { tk('__concat_str_list__'), delim_args(args) }
    end
  end

  macros['--'] = function (token, last)
    local args   = {}
    local length = #token.value

    for idx=1, length do
      table.insert(args, traverse(token.value[idx]))
    end

    return { tk('__merge_tables__'), delim_args(args) }
  end

  macros['$'] = function (token, last)
    local args = {}

    for idx=1, #token.value do
      table.insert(args, infer_operator(traverse(token.value[idx])))
    end

    return {
      tk('__curry__'), delim_args(args)
    }
  end

  macros['|>'] = function (token, last)
    local args   = token.value

    local output = {
      tk('(function(__piped__)'),
      ident(1),
      nl()
    }

    for idx=2, #args do
      table.insert(output, tk('__piped__'))
      table.insert(output, tk('=', 'operator'))
      table.insert(output, infer_operator(traverse(args[idx])))
      table.insert(output, tk('(__piped__)'))
      table.insert(output, nl())
    end

    table.insert(output, tk('return __piped__'))
    table.insert(output, ident(-1))
    table.insert(output, nl())
    table.insert(output, tk('end)('))
    table.insert(output, traverse(args[1]))
    table.insert(output, tk(')'))

    return output
  end

  macros['.'] = function (token, last)
    local output = '' .. token.value[1].value
    local args   = token.value

    for idx=2, #args do
      output = output .. '.' ..  args[idx].value
    end

    return {
      type     = 'literal',
      value    = output,
      position = token.position
    }
  end

  macros[':'] = function (token, last)
    local output = '' .. token.value[1].value
    local args   = token.value

    for idx=2, #args do
      if idx == #args then
        output = output .. ':' ..  args[idx].value
      else
        output = output .. '.' ..  args[idx].value
      end
    end

    return {
      type     = 'literal',
      value    = output,
      position = token.position
    }
  end

  macros['?'] = function (token, last)
    local test  = traverse(token.value[1])
    local block = traverse(orblock(neoblock(2, token.value)))

    return {
      tk('(function(it)'),
      ident(1),
      nl(),
      tk('if it ~= nil then'),
      ident(1),
      nl(),
      block,
      ident(-1),
      nl(),
      tk('end'),
      ident(-1),
      nl(),
      tk('end)('),
      test,
      tk(')')
    }
  end

  macros['!'] = function (token, last)
    local args = {}

    for idx=1, #token.value do
      table.insert(args, infer_operator(traverse(token.value[idx])))
    end

    return {
      tk('__option__'), delim_args(args)
    }
  end

  function macros.cond(token, last)
    local args   = token.value
    local length = #args

    local output = {
      tk('(function()'),
      ident(1),
      nl()
    }

    if args[1].type ~= 'list' then
      return err(args[1], 'Arguments list must be of [list] type.')
    end

    local tests = args[1].value

    local length = #tests / 2

    if (length - 1) % 2 == 1 then
      return err(tests[1],
        '[cond] wrongly used, please use a key-value pattern ' ..
        'with the last param being a block.')
    end

    for idx=1, length do
      local base  = ((idx - 1) * 2) + 1

      local test  = tests[base]
      local block = tests[base + 1]

      if idx == 1 then
        table.insert(output, tk('if '))
        table.insert(output, traverse(test))
        table.insert(output, tk(' then'))
      else
        table.insert(output, tk('elseif '))
        table.insert(output, traverse(test))
        table.insert(output, tk(' then'))
      end

      table.insert(output, ident(1))
      table.insert(output, nl())
      table.insert(output, traverse(orblock(block)))
      table.insert(output, ident(-1))
      table.insert(output, nl())
    end

    if #args >= 2 then
      table.insert(output, tk('else'))
      table.insert(output, ident(1))
      table.insert(output, nl())
      table.insert(output, traverse(orblock(neoblock(2, args))))
      table.insert(output, ident(-1))
      table.insert(output, nl())
    end

    table.insert(output, tk('end'))
    table.insert(output, ident(-1))
    table.insert(output, nl())
    table.insert(output, tk('end)'))

    return output
  end


  function macros.match(token, last)
    local args   = token.value
    local length = #args

    local output = {
      tk('(function(__ref__)'),
      ident(1),
      nl(),
      tk('local __jumptable__ = {'),
      ident(1),
      nl(),
    }

    if args[2].type ~= 'list' then
      return err(args[2], 'Arguments list must be of [list] type.')
    end

    local tests = args[2].value

    local length = #tests / 2

    if (length - 1) % 2 == 0 then
      return err(args[2],
        '[match] wrongly used, please use a key-value pattern ' ..
        'with the last param being a block.')
    end

    for idx=1, length do
      local base  = ((idx - 1) * 2) + 1

      local key   = tests[base]
      local value = tests[base + 1]

      table.insert(output, tk('['))
      table.insert(output, traverse(key))
      table.insert(output, tk(']'))
      table.insert(output, tk('=', 'operator'))
      table.insert(output, tk('function()'))
      table.insert(output, ident(1))
      table.insert(output, nl())
      table.insert(output, traverse(orblock(value)))
      table.insert(output, ident(-1))
      table.insert(output, nl())
      table.insert(output, tk('end'))

      if idx < length then
        table.insert(output, tk(','))
        table.insert(output, nl())
      end

    end

    table.insert(output, ident(-1))
    table.insert(output, nl())
    table.insert(output, tk('}'))
    table.insert(output, nl())
    table.insert(output, nl())
    table.insert(output, tk('local __match__ = __jumptable__[__ref__]'))
    table.insert(output, nl())
    table.insert(output, nl())
    table.insert(output, tk('if __match__ == nil then'))
    table.insert(output, ident(1))
    table.insert(output, nl())
    if #args >= 3 then
      table.insert(output, traverse(orblock(neoblock(3, args))))
    else
      table.insert(output, tk('return nil'))
    end
    table.insert(output, ident(-1))
    table.insert(output, nl())
    table.insert(output, tk('else'))
    table.insert(output, ident(1))
    table.insert(output, nl())
    table.insert(output, tk('return __match__()'))
    table.insert(output, ident(-1))
    table.insert(output, nl())
    table.insert(output, tk('end'))
    table.insert(output, ident(-1))
    table.insert(output, nl())
    table.insert(output, tk('end)('))
    table.insert(output, analyze(args[1]))
    table.insert(output, tk(')'))

    return output
  end

  function macros.module(token, last)
    local output   = {}
    local args     = token.value
    local location = ''

    for idx=1, #args do
      local name = traverse(args[idx]).value

      if location == '' then
        location = name
      else
        location = location .. '.' .. name
      end

      table.insert(output, tk('if '))
      table.insert(output, tk(location))
      table.insert(output, tk('==', 'operator'))
      table.insert(output, tk('nil then'))
      table.insert(output, ident(1))
      table.insert(output, nl())
      table.insert(output, tk(location))
      table.insert(output, tk('=', 'operator'))
      table.insert(output, tk('{}'))
      table.insert(output, ident(-1))
      table.insert(output, nl())
      table.insert(output, tk('end'))
      if idx < #args then
        table.insert(output, nl())
      end
    end

    return output
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
        if token.name == '=' then
          token.name = '=='
        end

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
        if #value == 0 then
          return strip(token)
        else
          return {
            strip(token),
            delim_args(value)
          }
        end
      elseif token.type == 'return' then
        return {
          tk('return '),
          traverse(token.value, true)
        }
      elseif token.type == 'list' then
        local output = {
          tk('__mark_list__'),
          tk('({'),
          ident(1),
          nl()
        }

        for idx=1, #token.value do
          table.insert(output, traverse(token.value[idx]))

          if idx < #token.value then
            table.insert(output, tk(','))
            table.insert(output, nl())
          end
        end

        table.insert(output, ident(-1))
        table.insert(output, nl())
        table.insert(output, tk('})'))

        return output
      elseif token.type == 'table' then
        local output = {
          tk('{'),
          ident(1),
          nl()
        }
        local length = (#token.value / 2)

        for idx=1, length do
          local index = ((idx - 1) * 2) + 1
          local key   = traverse(token.value[index])
          local value = traverse(token.value[index + 1])

          if key.type == 'literal' then
            table.insert(output, key)
          else
            table.insert(output, tk('['))
            table.insert(output, key)
            table.insert(output, tk(']'))
          end

            table.insert(output, tk('=', 'operator'))
            table.insert(output, value)

          if idx < length then
            table.insert(output, tk(','))
            table.insert(output, nl())
          end
        end

        table.insert(output, ident(-1))
        table.insert(output, nl())
        table.insert(output, tk('}'))

        return output
      elseif token.type == 'root' or token.type == 'block' then

        if token.type == 'block' then
          local func = traverse(token.value[1], last)

          if type(func) == 'table' and func.type == 'literal' then
            local args = {}

            function remove_ret(token)
              if token.type == 'return' then
                return token.value
              else
                return token
              end
            end

            for idx=2, #token.value do
              table.insert(args, remove_ret(token.value[idx]))
            end

            return traverse({
              type     = 'call',
              position = token.position,
              name     = func.value,
              value    = args
            })
          end
        end

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

  local colon = string.byte(':')
  local warnstr = false

  for idx=1, #iterable do
    local token = iterable[idx]

    if token.type == 'string-a' then
      local str = ''
      local t   = {}
      local function helper(line) table.insert(t, line) return "" end
      helper((token.value:gsub("(.-)\r?\n", helper)))

      for idx=1, #t do
        str = str .. t[idx]:gsub("^%s*(.-)%s*$", "%1")
        if idx < #t then
          str = str .. '\\\n'
        end
      end

      warnstr = true

      write(token, "'" .. str .. "'")
    elseif token.type == 'string-b' then
      local str = ''
      local t   = {}
      local function helper(line) table.insert(t, line) return "" end
      helper((token.value:gsub("(.-)\r?\n", helper)))

      for idx=1, #t do
        str = str .. t[idx]
        if idx < #t then
          str = str .. '\\\n'
        end
      end

      write(token, '"' .. str .. '"')
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
    elseif token.type == 'literal' then
      local str = token.value

      -- lisp case to snake case
      str = str:gsub('-', '_')

      -- operator func name support
      str = str:gsub('+', '_plus_')
      str = str:gsub('=', '_eq_')
      str = str:gsub('>', '_more_')
      str = str:gsub('<', '_less_')
      str = str:gsub('!', '_not_')
      str = str:gsub('?', '_maybe_')
      str = str:gsub('\\$', '_partial_')

      if str:byte(1) == colon or str:byte(#str) == colon then
        str = "'" .. str:gsub(':', '') .. "'"
      end

      write(token, str)
    elseif token.type ~= nil then
      if type(token.value) == 'table' then
        warn('[warn] Ignoring some token.\n')
      elseif type(token.value) == 'string' then
        write(token, token.value)
      end
    end
  end

  if warnstr then
    warn('Please stop using single quote strings. They are deprecated.')
  end

  -- return output
  return output
end

warn = function(...)
  local args = { ... }
  for idx=1, #args do
    io.stderr:write(args[idx])
    if idx < #args then
      io.stderr:write(' ')
    end
  end
  io.stderr:write('\n')
end

table.print = function(t)
  local print_r_cache={}
  local function sub_print_r(t,indent)
    if (print_r_cache[tostring(t)]) then
      warn(indent.."*"..tostring(t))
    else
      print_r_cache[tostring(t)]=true
      if (type(t)=="table") then
        for pos,val in pairs(t) do
          if (type(val)=="table") then
            warn(indent.."["..pos.."] => "..tostring(t).." {")
            sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
            warn(indent..string.rep(" ",string.len(pos)+6).."}")
          elseif (type(val)=="string") then
            warn(indent.."["..pos..'] => "'..val..'"')
          else
            warn(indent.."["..pos.."] => "..tostring(val))
          end
        end
      else
        warn(indent..tostring(t))
      end
    end
  end
  if (type(t)=="table") then
    warn(tostring(t).." {")
    sub_print_r(t,"  ")
    warn("}")
  else
    sub_print_r(t,"  ")
  end
  warn()
end

