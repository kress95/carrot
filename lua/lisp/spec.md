Lisp.lua @ 0.9.7
================

This is a specification of the Lisp dialect for LuaJIT 2.x.y environment.

This is a clojure-based lisp dialect with sugary syntax, the language is very
close and integrated to Lua so it won't be portable to another environments.

The 0.9.x milestone is reached after bootstrapping the compiler, then reaching
1.0.x after the finishing touches.

Yes, 1.x series will not launch that soon.

###### Contents

* Nomenclature
  * Form
  * Macro
  * Imperative
  * Declarative
  * Functional
  * Block
  * Function
  * Lambda Function
  * Procedure
  * Truthy
  * Falsy
  * Quoting
  * Unquoting

* Lexical Analysis
  * Identifiers
  * Numbers
  * Booleans
  * Strings
  * Lists
  * Maps
  * Forms
  * Parameters

* Imperative Macros (core)
  * proc
  * for
  * for-in
  * reserve-local
  * if-statement
  * switch
  * return
  * break
  * assign

* Special Macros (core)
  * def
  * fun
  * do
  * macro
  * prefix
  * infix
  * import
  * global
  * at
  * length `#`
  * dot access `.`
  * colon access `:`
  * partial application `$`

* Compile-time Macros (core)
  * @prop
  * @type
  * @arity
  * @params
  * @assert

* Standard Macros (user-land)
  * let
  * if
  * when
  * when-not
  * cond
  * match
  * concat objects `++`
  * merge strings `--`
  * pipe `|>`
  * maybe `?`
  * option `!`

* Operators
  * and `&&`
  * or `||`
  * not `~`
  * equals `=`
  * not equals `~=`
  * greater than `>`
  * lesser than `<`
  * greater or equal to `>=`
  * lesser or equal to `<=`
  * addition `+`
  * subtraction `-`
  * division `/`
  * multiplication `*`
  * power `^`
  * remainder `%`
  * modulo `%%`

* Bitwise Operators
  * AND `&:`
  * OR `|:`
  * NOT `~:`
  * XOR `^:`
  * RSHIFT `>>:`
  * LSHIFT `<<:`

* Documentation Macros
  * docstr
  * defdoc
  * fundoc


Nomenclature
------------

###### Contents

* Form
* Macro
* Imperative
* Declarative
* Functional
* Block
* Function
* Lambda Function
* Procedure
* Truthy
* Falsy
* Quoting
* Unquoting

### Form

A form is the use of a macro, there are several forms included by default.

### Macro

A macro is the definition of a form. Macros may be created by the
compiler or user. The default set of macros is called the _Core Macros_.

### Imperative

Most of the world outside functional programming, we usually
make a layer of abstraction over the imperative world and force
the user to survive solely with functional programming techniques.

But not here, you may resort to imperactive forms when writing
macros, just don't use them when writing functions

### Declarative

A more abstract approach to programming, use it wisely, it's your friend.
The main problem with problem declarative programming is it's
unpredictability.

### Functional

Functional programming is a programming style where math is
applied to programming. Using functions to build predictable
and manageable complex structures.

Functional Programming is the ideal paradigm for concurrence
and parallelism.

### Block

A block is a delimited block of code.
A form that won't invoke anything is inferred to a block.

### Function

A function is a code block where no side effect is allowed, you may
give names to functions and refer them by their name, or make
them anonymous using lambda functions.

### Lambda Function

A lambda function is a function without a name.
They are less verbose to declare and very handy.

### Procedure

Procedures are like functions but you may use imperative macros within it.
Use them wisely.

Like any imperative macro, you can only it within a macro definition.

### Truthy

A truthy value is a value that is not `nil` or `false`.

### Falsy

The only false values are `nil` and `false`.

### Quoting

Quoting is the action of returning AST.
Quoted is inserted in the last place it returns.

### Unquoting

The act of evaluating quoted content.
You may only unquote inside of macro definition blocks.




Lexical Analysis
----------------

###### Contents

* Identifiers
* Numbers
* Booleans
* Strings
* Lists
* Maps
* Forms
* Parameters


### Identifiers

A valid identifier passes the `/[a-zA-Z][^\s\\]+/` test.

Any `-` found is converted into `_`.


### Numbers

Every valid Lua number is a valid number.


### Booleans

Just `false` and `true` are booleans.


### Strings

The same as Lua strings, but may span multiple lines.

There are three special string types:

* __Single Quotes:__ Single quotes string are trimmed at each line.

* __Double Quotes:__ Double quotes string are just raw strings.

* __Colon String:__ Strings prefixed and/or postfixed by colons passes
a test to check if it is a valid identifier and any `-` is converted into `_`.


### Lists

Lists are declared using square brackets, simple like that.


### Maps

Maps are declared using curly brackets, sort of like `{ key value }`.
The best way is to use _colon strings_ as keys: `{ key: 'value' }`.


### Forms

Forms are declared using parens, forms usually invoke something, when a form
won't invoke anything they are inferred as a code block.


### Parameters

Remember: variadic functions has no function application support.

#### The Splat

Most of the functions and macros have fixed arity, to declare a function
or macro with alternative arity, use but `...` after parameter name:


    (fun example [a b...] (b))


Any function using the splat is a variadic function.


#### Optional Parameters

Optional parameters are also supported, just put a `?` after the parameter
name:

    (fun example [a b? c] ([a b c]))

Required parameters have priority over optional ones, so calling
`(example 1 2)` will define `a = 1` and `c = 2`.

Functions using optional parameters don't become variadic, but they will
ignore that the parameters are optional and will require them.




Imperative Macros (core)
----------------------

Imperative macros are hairy macros forbidden everywhere but macro definitions.
And even there they have restrictions, you may never evaluate a
imperative form at compile time.

###### Contents

* proc
* for
* for-in
* reserve-local
* if-statement
* switch
* return
* break
* assign


### (proc name? [params*] block...)

Builds a procedure with no implicit return.

Not mentioning a name compiles into anonymous procedures.

###### Exaxample

    (proc name [a b c] (print (+ a (- b c))))

    (proc [a b c] (print (+ a (- b c))))

###### Generates

    function name(a, b, c)
      print(a + (b - c))
    end

    function (a, b, c)
      print(a + (b - c))
    end


### (for (name value) iterator block...)

Builds a indexed iterator block.

###### Example Code:

    (for (idx 1) #list block...)

###### Compiled:

    for idx = 1, #list do
      block...
    end


### (for-in [params*] iterator block...)

Builds a parametized iterator block.

###### Example Code:

    (for-in [k v] (pairs hashmap) block...)

###### Compiled:

    for k,v in pairs(hashmap) do
      block...
    end


### (if-statement test then else?)

Evaluates `test`, when truthy evaluate `then`, otherwise yields the evaluation of `else`.

###### Example

  (if-statement true (print 'true') (print 'false'))

###### Generates

    if true then
      print('true')
    else
      print('false)
    end


### (switch [tuples*] else?)

Switch builds a if/elseif/else statement, tuple must be formated like `test -procedure`, else is a optional default form.

###### Example

    (switch [(a b) (print 10)
             (< a b) (print 20)]
            (print 'fail'))

###### Generates

    if a b then
      print(10)
    elseif a < b then
      print(20)
    else
      print('fail')
    end


### (return value)

Simply returns a value.

###### Example

    (proc k-ten [] (return 10))

###### Generates

    function k_ten()
      return 10
    end


### (break)

Introduces a break statement.

###### Example

    (for (idx 1) #list (break))

###### Generates

    for idx = 1, #list do
      break
    end


### (assign name value)

Mutates `name` to `value`.
When name is not the name of a local, it defines a global.

###### Example

    (assign varname 10)

###### Generates

    varname = 10




Special Macros (core)
--------------------

Special macros are core macros that you may use without restrictions.

###### Contents

* def
* fun
* do
* macro
* prefix
* infix
* import
* global
* at
* length `#`
* dot access `.`
* colon access `:`
* partial application `$`


### (def name value)

Defines a local variable named `name` with the value `value`.

###### Example

    (def varname 'varvalue')

###### Generates

    local varname = 'varvalue'


### (fun name [params*] ...block)

Defines a function, behaves sort of like a `proc` with an implicit return.
Unlike `procs` and `macro` definitions, functions can't include the use of any imperative macro.

###### Example

    (fun sum [a b] (+ a b))

###### Generates

    function sum(a, b)
      return a + b
    end


### (do [params*] ...block)

Builds a lambda function, behaves the same as functions, but don't hold any name.

Aliased as `\`, and you're encouraged to use this alternative syntax.

###### Example

    (do [a b] (+ a b))
    (\ [a b] (+ a b))

###### Generates

    (function (a, b)
      return a + b
    end)

    (function (a, b)
      return a + b
    end)


### (macro name [params*] ...block)

Builds a `user-land` macro.

When the compiler detects a macro call, it will evaluate it immediately.
The yielded value replaces the macro call.

Much of the language is composed of `user-land` macros, try to not reinvent the wheel when using them.

###### Example

    (macro sum [a b] (` (+ (´ a) (´ b))))
    (sum 1 2)

###### Generates

    1 + 2


### (macro name [params*] ...block)

Builds a `user-land` macro.

When the compiler detects a macro call, it will evaluate it immediately.
The yielded value replaces the macro call.

Much of the language is composed of `user-land` macros, try to not reinvent the wheel when using them.

###### Example

    (macro sum [a b] (` (+ (´ a) (´ b))))
    (sum 1 2)

###### Generates

    1 + 2


### (prefix symbol result?)

Builds a prefix operator.
`result` is an optional string value for transforming the symbol into another thing.

###### Example

    (prefix ~ 'not')
    (~ true)

###### Generates

    not true


### (infix symbol result?)

Builds a infix operator of given symbol.
Like with prefix, `result` is an optional string value for transforming the symbol into another thing.

###### Example

    (infix +)
    (+ 1 2)
    (infix * '-')
    (* 1 2)

###### Generates

    1 + 2
    1 - 2


### (import file macros...)

Include named `macros` from `file` (a string).
To enable renaming included macros, you may use a list.

###### Example

    (import 'example-file.ll' sum)
    (import 'example-file2.ll' [original1 renamed1
                                original2 renamed2])

###### Generates

    ; this macro generates no code when used


### (global name value)

Like `def`, but global, this special form is forbidden everywhere but
file's root scope. Also, you can't redefine locals as globals, so take care.

###### Example

    (global ten 10)

###### Generates

    ten = 10


### (at key name)

Retrieves table's value at `key`.

###### Example

    (at 1 list)

###### Generates

    list[1]


### (# name)

Get length of a table or string.

###### Example

    (# list)

###### Generates

    #list


### (. names...)

Property access using brackets and dots.

###### Example

    (. list 1 name)

###### Generates

    list[1].name


### (: names...)

Function access using colons.

###### Example

    (: list 1 name func)

###### Generates

    list[1].name:func


# ($ function args...)

Curry and partial application macro, very hackish.
Works completly differently when used with operators.

When used with functions, it includes a definition of the `__curry__` function
in the beginning of the file, it's hackish, but optimal.

Use the `--no-curry` flag to not include the curry function at all.


###### Example

    ($ +)

    ($ + 1)

    (fun sum [a b] (+ a b))

    ($ sum 1)

###### Generates

    if __curry__ == nil then
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
    end

    function (a, b)
      return a + b
    end

    function (b)
      return 1 + b
    end

    function sum(a, b)
      return a + b
    end

    __curry__(sum, 1)




Compile-time Macros (core)
-------------------------

While the language and runtime uses duck typing, the macro system has some
type check capabilities, most of it is done so you can build macros that
talk with each other.


###### Contents

* @prop
* @type
* @arity
* @params
* @assert


### (@prop name value? block)

Sets a property when called with 3 parameters and gets property when
called with just 2.


###### Example

  ; set propety to block
  (@prop safe true (´ (+ 1 2)))

  ; get propety from block
  (@prop safe (´ (+ 1 2)))


### (@type value? block)

Sets type when called with 2 parameters and gets type when called with just 1.


###### Example

    ; set type to block
    (@type Potato (´ (+ 1 2)))

    ; get type from block
    (@type (´ (+ 1 2)))


### (@arity)

Returns the arity of the current macro. No further explaination needed :)


### (@params)

Returns a list with the parameters used to call the macro.
The returned params have detailed information for debug purposes.


### (@assert something [type] message?)

Useful for error messages.

Asserts `something` type is present on the `[type]` list.
When `message?` is present, it shows it instead of the generic error message.


###### Example

    ; throws: 'The 1st param of the macro X should be of the type List.'
    (@assert (at 1 @params) [List])

    ; throws: 'Foo bar.'
    (@assert (at 1 @params) [List] 'Foo bar.')


Standard Macros (user-land)
--------------------------

These macros are defined within the Standard Lisp Library for Lua (SLL).

They are user-land macros included by default into the language.

###### Contents

* let
* if
* when
* when-not
* cond
* match
* concat objects `++`
* merge strings `--`
* pipe `|>`
* maybe `?`
* option `!`


### (let [tuples...] block)

Defines variable with a lexical block.

###### Example

    (let [a 10 b 20] (+ a b))

###### Generates

    (function(a, b)
      return a + b
    end)(10, 20)


### (if test then else?)

If expression. When `test` is truthy evaluates `then`, when `falsy` evaluates
`else?` (when present), yields the evaluation result or nil.

###### Example

    (if (= a 10) (/ a 2) (* a 2))

###### Generates

    (function()
      if a == 10 then
        return a / 2
      else
        return a * 2
      end
    end)()


### (when test then...)

Like if, but variadic with no else.

###### Example

    (when (= a 10) (def b (/ a 2)) (* a b))

###### Generates

    (function()
      if a == 10 then
        local b = a / 2
        return a * b
      end
    end)()


### (when-not test then...)

Like when, but evaluates when value is falsy.

###### Example

    (when-not (= a 10) (def b (/ a 2)) (* a b))

###### Generates

    (function()
      if not (a == 10) then
        local b = a / 2
        return a * b
      end
    end)()


### (cond [tuples...] else?)

Like switch, but as an expression.

###### Example

    (cond [(a b) (+ a b)
           (< a b) (- a b)]
          (0))

###### Generates

    (function ()
      if a b then
        return a + b
      elseif a < b then
        return a - b
      else
        return 0
      end
    end)()


### (match value [tuples...] else?)

Performs pattern matching.

###### Example

    (match a [1 (+ a b)
              2 (- a b)]
             (0))

###### Generates

    (function ()
      local __jumptable__ = {
        [1] = function ()
          return a + b
        end,
        [2] = function ()
          return a - b
        end
      }

      local __else__ = function()
        return 0
      end

      local __match__ = __jumptable__[a]

      if __match__ == nil then
        return __else__()
      else
        return __match__()
      end
    end)()


### (++ list-or-maps...)

Concatenates tables and lists.

###### Example

    (++ [1 2] [3 4] [5 6])
    (++ { a: '1' } { b: '2' } { c: '3'})

###### Generates

    (function (...)
      local out  = { }
      local args = ...

      for idx=1, #args do
        local curr = args[idx]

        for idx2=1, #curr do
          table.insert(out, curr[idx])
        end
      end

      return out
    end)({1, 2}, {3, 4}, {5, 6})

    (function (...)
      local out  = { }
      local args = ...

      for idx=1, #args do
        local curr = args[idx]

        for k,v in pairs(curr) do
          out[k] = v
        end
      end

      return out
    end)({1, 2}, {3, 4}, {5, 6})


### (-- strings...)

Performs pattern matching.

###### Example

    (-- 'hello, ' 'world! ' ':D')

###### Generates

    (function (...)
      local out  = ''
      local args = ...

      for idx=1, #args do
        out = out .. args[idx]
      end

      return out
    end)('hello, ', 'world! ', ':D')


### (|> value functions...)

Pipes values trough functions

###### Example

    (fun sum10 [a] (+ a 10))

    (fun div2 [a] (/ a 2))

    (fun sub1 [a] (- a 1))

    (|> 10 sum10 div2)

###### Generates

    function sum10(a)
      return a + 10
    end

    function div2(a)
      return a / 2
    end

    function sub1(a)
      return a -1
    end

    (function (__out__)
      __out__ = sum10(__out__)
      __out__ = div2(__out__)
      return sub1(__out__)
    end)(10)


# (? test block...)

Evaluates and yields `block...` when `test` is not `nil`.

###### Example

    (? a (+ a 10))

###### Generates

    (function()
      if a ~= nil then
        return a + 10
      end
    end)()


# (! values...)

Returns last value that is not nil.

###### Example

    (! 1 2 3 nil 4 nil)

###### Generates

    (function(...)
      local args = ...
      local out  = nil

      for idx=1, #args do
        local value = args[idx]
        if value ~= nil then
          out = value
        end
      end

      return out
    end)(1, 2, 3, nil, 4, nil)




Operators
---------

###### Contents

* and `&&`
* or `||`
* not `~`
* equals `=`
* not equals `~=`
* greater than `>`
* lesser than `<`
* greater or equal to `>=`
* lesser or equal to `<=`
* addition `+`
* subtraction `-`
* division `/`
* multiplication `*`
* power `^`
* remainder `%`
* modulo `%%`

Most of the operators pass no transformations upon compiling, these operators are not described here.


###  Simple Operators

Name   | Alternative | Compiles
-------|-------------|-----------
and    | &&          | and
or     | \|\|        | or
not    | ~           | not


### (%% a b)

A proper modulo operator.

###### Example

    (%% 2 4)

###### Generates

    ((2 % 4) + 4) % 4




Bitwise Operators
-----------------

Bitwise operators are not real operators, they are defined as standard macros and yield function calls.

###### Contents

* AND `&:`
* OR `|:`
* NOT `~:`
* XOR `^:`
* RSHIFT `>>:`
* LSHIFT `<<:`


### Simple Operators

Name   | Alternative | Compiles
-------|-------------|-----------
AND    | &:          | bit.band
OR     | \|:         | bit.bor
NOT    | ~:          | bit.bnot
XOR    | ^:          | bit.bxor
RSHIFT | \>\>:       | bit.rshift
LSHIFT | <<:         | bit.lshift




Documentation Macros
--------------------

The language has default macros for writing documentation.

To receive documentation as json, use the `--doc` flag.

###### Contents

* docstr
* defdoc
* fundoc


### (docstr docstring)

A simple documentation string. Use it to explain something.


###### Example

    (docstr 'This file implements the foo system in the terms of bar.
             Foo yields baz.')


### (defdoc name type docstring)

Declares documentation for exported and global values.

`name` is the exported identifier and `type` must be the type of the exported
value. Then use `docstring` to describe it:


###### Example

    (defdoc ten number 'A plain simple number ten.')
    (def ten 10)


### (fundoc name [tuples...] type docstring)

Declares documentation for exported and global functions.

`name` is the exported identifier, `tuples` the describe expected param types
and `type` must be the returned value type.

Then use `docstring` to describe the function:


###### Example

    (fundoc sum [a number b number] number
            'Performs a simple sum of two numbers.')
    (fun sum [a b] (+ a b))




Micro Implementation
--------------------

The micro implementation is the `0.8` or lower version of the language.

This implementation has less features, but builds a solid ground for
building a bootstrapped implementation, the micro implementation
changes couple things to speed-up development:

* No macro definition tools such as _Imperative Macros_ and
_Compile-time Macros_.
* No _Documentation Macros_ and documentation tools.
* The _Standard Macros_ are defined as _special macros_ instead of
_user-land macros_
macros.
* _Special Macros_ not included:
  * macro
  * prefix
  * infix
  * import



----------

That's all folks!
