--[[

Lex rules:

  ;   - comment, closed by a newline
  \   - string escape
  #   - comment form
(   ) - usual form
{   } - form for map-like tables
[   ] - form for list-like tables
'   ' - form for strings
"   " - also a form for strings

Anything not found in the list is tagged as a literal. (I'm a lazy bum)

--]]

-- character byte codes
local chars   = {}
chars.space   = string.byte(' ')
chars.tab     = string.byte('\t')
chars.comma   = string.byte(';')
chars.escape  = string.byte('\\')
chars.hashtag = string.byte('#')
chars.lparen  = string.byte('(')
chars.rparen  = string.byte(')')
chars.lcurly  = string.byte('{')
chars.rcurly  = string.byte('}')
chars.lsquare = string.byte('[')
chars.rsquare = string.byte(']')
chars.sqstr   = string.byte("'")
chars.dqstr   = string.byte('"')
chars.newline = string.byte('\n')

-- mode changing characters
local cmode  = {
  normal  = {},
  comment = {},
  astr    = {},
  bstr    = {}
}

-- normal mode
cmode.normal[chars.comma]   = 'comment'
cmode.normal[chars.hashtag] = 'heredoc' -- no generalized rules
cmode.normal[chars.lparen]  = '<paren'
cmode.normal[chars.rparen]  = '>paren'
cmode.normal[chars.lcurly]  = '<curly'
cmode.normal[chars.rcurly]  = '>curly'
cmode.normal[chars.lsquare] = '<square'
cmode.normal[chars.rsquare] = '>square'
cmode.normal[chars.sqstr]   = 'astr'
cmode.normal[chars.dqstr]   = 'bstr'
cmode.normal[chars.newline] = 'ignore'
cmode.normal[chars.space]   = 'ignore'
cmode.normal[chars.tab]     = 'ignore'

-- comment mode
cmode.comment[chars.newline] = 'normalize'

-- single quote string mode
cmode.astr[chars.escape] = 'escape'
cmode.astr[chars.sqstr]  = 'normalize'

-- single quote string mode
cmode.astr[chars.escape]  = 'escape'
cmode.astr[chars.newline] = 'newline'
cmode.astr[chars.sqstr]   = 'normalize'

-- double quotes string mode
cmode.bstr[chars.escape]  = 'escape'
cmode.bstr[chars.newline] = 'newline'
cmode.bstr[chars.dqstr]   = 'normalize'

function lex(input)
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
  local heredoc = false    -- heredoc mode
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
        disabled = heredoc,
        position = pos(accum.line, accum.column, line, column)
      })

      accum.value = ''
    end
  end

  -- main loop
  for idx = 1, #input do

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
      if mode == 'normal' then
        acc(idx)
      else
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
            disabled = heredoc,
            position = pos(line, column)
          })
        elseif closing then
          if p_form == c_form then
            table.remove(forms)
            table.insert(output.tokens, {
              type     = c_form,
              value    = 'end',
              disabled = heredoc,
              position = pos(line, column)
            })
          else
            err(p_form, c_form)
          end
          heredoc = false
        elseif mode == 'heredoc' then
          heredoc = true
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
        escape = true
      elseif escape or mode ~= 'normalize' then
        acc(idx)
        escape = false
      else
        acc_reset('string')
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
