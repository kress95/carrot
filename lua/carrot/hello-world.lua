-- simple fibonacci function that works
function fib(n)
    return return (function()
        if n < 3 then
            return 1
        else
            return fib(n - 1) + fib(n - 2)
        end
    end)()
end
-- testing fib
print(fib(10))
-- optimized string concatenation
print(('hello' .. '' .. 'world'))
-- let's define some locals
local hello = 'hello'
local world = 'world'
-- unoptimized string concatenation
print(__concat_str_list__(hello, '', world))
-- pipe and partial application test
print((function(__piped__)
    __piped__ = __curry__((function(y, x) return x * y end), 3)(__piped__)
    __piped__ = __curry__((function(y, x) return x / y end), 2)(__piped__)
    return __piped__
end)(10))
-- recursive map function
function map(func, list)
    return local output = {
        
    }
    function recur(curr)
        return return (function()
            if curr <= (#list) then
                return table.insert(output, func(list[curr]))
                recur(curr + 1)
                return output
            end
        end)()
    end
    return recur(1)
end
-- testing the map function
(function(list)
    return return (function(__piped__)
        __piped__ = __curry__(map, __curry__((function(y, x) return x * y end), 2))(__piped__)
        __piped__ = table.print(__piped__)
        return __piped__
    end)(list)
end)(__mark_list__({
    1,
    2,
    3
}))
(function(__piped__)
    __piped__ = __curry__(map, __curry__((function(y, x) return x * y end), 2))(__piped__)
    __piped__ = print(__piped__)
    return __piped__
end)(__mark_list__({
    1,
    2,
    3
}))
(function(it)
    if it ~= nil then
        return return it * 2
    end
end)(10)
print(__option__(1, 2, nil, 3, nil))
(function()
    if 10 == 10 then
        return print(10)
    elseif 10 == 20 then
        return print(20)
    elseif 10 == 30 then
        return print(30)
    else
        return return print(40)
    end
end)
(function(__ref__)
    local __jumptable__ = {
        [10] = function()
            return print(10)
        end,
        [20] = function()
            return print(20)
        end
    }
    
    local __match__ = __jumptable__[__ref__]
    
    if __match__ == nil then
        return return print(30)
    else
        return __match__()
    end
end)(10)
function _more__more__eq_(x, y)
    return x:bind(y)
end
