lisp                     | lua
-------------------------------------------------
[1 2 3 4 5 6 7]          | { 1, 2, 3, 4, 5, 6, 7 }
{ key 'value' }          | { key = 'value' }
(let x y)                | local x = y
(def x y)                | x = y
(fun name (args) (body)) | function name(args) return body end
(λ (args) (body))        | function(args) return body end
