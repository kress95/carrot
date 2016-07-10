
function directory()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*/)")
end

arg[1]
