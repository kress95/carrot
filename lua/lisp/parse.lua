-- monadic operators
local monadic = {
  '!',  -- revert number
  '~',  -- revert boolean
}

-- dyadic operators
local dyadic = {
  '--', -- string concatenation

  -- numeric operators
  '+',  -- plus
  '-',  -- minus
  '/',  -- div
  '*',  -- mult
  '^',  -- pow
  '%',  -- remainder
  '%%', -- mod

  -- logic operators
  '=',  -- equal
  '!=', -- not equal
  '>',  -- greater than
  '<',  -- lesser than
  '>=', -- equal or greater than
  '<=', -- equal or lesser than
  '&&', -- and operator
  '||', -- or operator
}

-- variadic operators
local macros = {
  '++', -- table concatenation

  -- bitwise operators
  '.&.',   -- bitwise &
  '.|.',   -- bitwise |
  '.^.',   -- bitwise ^
  '.~.',   -- bitwise ~
  '.<<.',  -- bitwise <<
  '.>>.',  -- bitwise >>
  '.>>>.', -- bitwise >>>

  -- macros
  '.',   -- partial application
  '?',   -- do block when value is not nil
  '|>',  -- pipe operator
  '\\',  -- lambda function
  'let', -- define value
  'fun', -- define function
  'def', -- define value (use let most of times pls)
  'var'  -- define global value
}

-- detector
local detector = {}

for k,v in pairs(monadic) do detector[v] = 'monadic' end
for k,v in pairs(dyadic)  do detector[v] = 'dyadic'  end
for k,v in pairs(macros)  do detector[v] = 'macro'   end

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function parse(lexres)
  if lexres.result.error then
    return lexres
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

  for idx = 1, #lexres.tokens do
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
      pop_scope()
    elseif mode == 'literal' then
      table.insert(last_scope.value, token)
    end
  end

  return output
end
