if lisp == nil then
  lisp = {}
end

-- character byte codes
local chars   = {
  space   = string.byte(' '),
  tab     = string.byte('\t'),
  comma   = string.byte(';'),
  escape  = string.byte('\\'),
  lparen  = string.byte('('),
  rparen  = string.byte(')'),
  lcurly  = string.byte('{'),
  rcurly  = string.byte('}'),
  lsquare = string.byte('['),
  rsquare = string.byte(']'),
  sqstr   = string.byte("'"),
  dqstr   = string.byte('"'),
  newline = string.byte('\n')
}

-- mode changing characters
local cmode  = {
  -- normal mode
  normal = {
    [chars.comma]   = 'comment',
    [chars.lparen]  = '<paren',
    [chars.rparen]  = '>paren',
    [chars.lcurly]  = '<curly',
    [chars.rcurly]  = '>curly',
    [chars.lsquare] = '<square',
    [chars.rsquare] = '>square',
    [chars.sqstr]   = 'astr',
    [chars.dqstr]   = 'bstr',
    [chars.newline] = 'ignore',
    [chars.space]   = 'ignore',
    [chars.tab]     = 'ignore'
  },

  -- comment mode
  comment = {
    [chars.newline] = 'normalize'
  },

  -- single quote string mode
  astr = {
    [chars.escape] = 'escape',
    [chars.sqstr]  = 'normalize'
  },

  -- double quotes string mode
  bstr = {
    [chars.escape]  = 'escape',
    [chars.newline] = 'newline',
    [chars.dqstr]   = 'normalize'
  }
}

-- lisp.lex, the lexer
function lisp.lex(input)
  -- output object
  local output = {
    tokens = {},
    result = {
      error   = false,
      message = ''
    }
  }

  -- commom variables
  local p_mode  = 'normal' -- mode tracker
  local forms   = {}       -- form tracker
  local line    = 1        -- current line
  local column  = 0        -- current column
  local escape  = false    -- escape mode

  -- accumulator information
  local accum = {
    line   = 1, -- init line
    column = 0, -- init column
    value  = '' -- empty value
  }

  -- error function
  function err(wanted, got)
    -- set skip mode
    mode = 'error'

    -- set output to represent error
    output.tokens = {}
    output.result.error = true

    -- lex error message
    if wanted ~= nil and got == nil then
      -- for unexpected end of file
      output.result.message =
        'Unexpected end of file, expected [' .. wanted .. '].'
    elseif wanted == nil and got ~= nil then
      -- for unexpected tokens
      output.result.message =
        'Unexpected [' .. got .. '] at ' ..
        line .. ':' .. column .. '.'
    elseif wanted ~= nil and got ~= nil then
      -- for misplaced tokens
      output.result.message =
        'Expected [' .. wanted .. '] at ' ..
        line .. ':' .. column .. ', ' ..
        'But got [' .. got .. '].'
    end
  end

  -- returns position
  function pos(l1, c1, l2, c2)
    if l2 and c2 then
      return l1 .. ':' .. c1 .. '~' .. l2 .. ':' .. c2
    else
      return l1 .. ':' .. c1
    end
  end

  -- accumulate function
  function acc(index)
    if is_acc() == false then
      accum.line   = line
      accum.column = column
    end
    accum.value = accum.value .. string.sub(input, index, index)
  end

  -- is accumulating
  function is_acc()
    return string.len(accum.value) > 0
  end

  -- reset accumulation
  function acc_reset(type)
    if is_acc() then
      table.insert(output.tokens, {
        type     = type,
        value    = accum.value,
        position = pos(accum.line, accum.column, line, column)
      })

      accum.value = ''
    end
  end

  local input_length = #input

  -- main loop
  for idx = 1, input_length do

    if mode == 'error' then
      break
    end

    -- current character and current mode
    local char = input:byte(idx)
    local mode = cmode[p_mode][char]

    -- fallback next mode to normal
    if mode == nil then
      mode = 'normal'
    end

    -- is opening or closing a form
    local mode_fl = string.sub(mode, 1, 1)
    local opening = mode_fl == '<'
    local closing = mode_fl == '>'
    local c_form  = ''
    local p_form  = ''

    -- detect form type when opening or closing a form
    if opening or closing then
      -- detect form type when opening a form
      if char == chars.lparen      or char == chars.rparen then
        c_form = 'paren'
      elseif char == chars.lcurly  or char == chars.rcurly then
        c_form = 'curly'
      elseif char == chars.lsquare or char == chars.rsquare then
        c_form = 'square'
      end
    end

    -- detect needed form type
    if closing then
      p_form = forms[table.maxn(forms)]
    end

    -- source location information
    if char == chars.newline then
      line   = line + 1
      column = 1
    else
      column = column + 1
    end

    if p_mode == 'normal' then
      if mode == 'normal' and idx < input_length then
        acc(idx)
      else
        if mode == 'normal' and idx == input_length then
          acc(idx)
        end

        if is_acc() then
          local acc_type = 'literal'

          if accum.value == 'false' or accum.value == 'true' then
            acc_type = 'boolean'
          elseif tonumber(accum.value) ~= nil then
            acc_type = 'number'
          end

          acc_reset(acc_type)
        end

        if opening then
          table.insert(forms, c_form)
          table.insert(output.tokens, {
            type     = c_form,
            value    = 'begin',
            position = pos(line, column)
          })
        elseif closing then
          if p_form == c_form then
            table.remove(forms)
            table.insert(output.tokens, {
              type     = c_form,
              value    = 'end',
              position = pos(line, column)
            })

            mode = forms[table.maxn(forms)]
          else
            err(p_form, c_form)
          end
        elseif mode ~= 'ignore' then
          p_mode = mode
        end
      end
    elseif p_mode == 'comment' then
      if mode == 'normalize' then
        acc_reset('comment')
        p_mode = 'normal'
      else
        acc(idx)
      end
    elseif p_mode == 'astr' or p_mode == 'bstr' then
      if mode == 'escape' then
        acc(idx)
        escape = true
      elseif escape or mode ~= 'normalize' then
        acc(idx)
        escape = false
      else
        acc_reset(p_mode)
        p_mode = 'normal'
      end
    end
  end

  local forms_len = table.maxn(forms)

  if forms_len > 0 then
    err(forms[forms_len])
  elseif p_mode == 'astr' then
    err('single-quote')
  elseif p_mode == 'bstr' then
    err('double-quotes')
  end

  return output
end
