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

for k,v in pairs(monadic) do detector[k] = v end
for k,v in pairs(dyadic)  do detector[k] = v end
for k,v in pairs(macros)  do detector[k] = v end

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function parse(lexres)
  if lexres.result.error then
    return lexres
  end

  local output = {
    ast    = {},
    result = {
      error   = false,
      message = ''
    }
  }

  local mode = '' -- modes: form / list / map

  for idx = 1, #lexres.tokens do
    print(idx)
  end

end
