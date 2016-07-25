table.print = function(t)
  local print_r_cache={}
  local function sub_print_r(t,indent)
    if (print_r_cache[tostring(t)]) then
      print(indent.."*"..tostring(t))
    else
      print_r_cache[tostring(t)]=true
      if (type(t)=="table") then
        for pos,val in pairs(t) do
          if (type(val)=="table") then
            print(indent.."["..pos.."] => "..tostring(t).." {")
            sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
            print(indent..string.rep(" ",string.len(pos)+6).."}")
          elseif (type(val)=="string") then
            print(indent.."["..pos..'] => "'..val..'"')
          else
            print(indent.."["..pos.."] => "..tostring(val))
          end
        end
      else
        print(indent..tostring(t))
      end
    end
  end
  if (type(t)=="table") then
    print(tostring(t).." {")
    sub_print_r(t,"  ")
    print("}")
  else
    sub_print_r(t,"  ")
  end
  print()
end

require 'lisp.lex'
require 'lisp.parse'
require 'lisp.build'

local src = [[
  ; simple fibonacci function that works
  (fun fib [n]
    (if (< n 3)
      1
      (+ (fib (- n 1)) (fib (- n 2)))))

  ; testing fib
  (print (fib 10))

  ; optimized string concatenation
  (print (++ 'hello' ' ' 'world'))

  ; let's define some locals
  (def hello 'hello')
  (def world 'world')

  ; unoptimized string concatenation
  (print (++ hello ' ' world))

  ; pipe and partial application test
  (print (|> 10 ($ * 3) ($ / 2)))

  ; recursive map function
  (fun map [func list]
    (def output {})
    (fun recur [curr]
       (if (<= curr (# list))
         (((. table insert) output (func (at curr list)))
          (recur (+ curr 1))
          (output))))
    (recur 1))

  ; testing the map function
  (let [list [1 2 3 ] ] (|> list ($ map ($ * 2)) (. table print)))
  (|> [1 2 3] ($ map ($ * 2)) print)

  (? 10 (* it 2))
  (print (! 1 2 nil 3 nil))

  (cond [(= 10 10) (print 10)
         (= 10 20) (print 20)
         (= 10 30) (print 30)]
        (print 40))

  (match 10 [10 (print 10)
             20 (print 20)]
            (print 30))
]]

local results = lisp.build(lisp.parse(lisp.lex(src)))

print('-----------')

if results.result.error then
  table.print(results.result.message)
else
  print(results.source)
end
