```ocaml
let add x y = x +. y

let subtract x y = x -. y

let multiply x y = x *. y

let divide x y =
  if y = 0.0 then
    Error "Error: Division by zero"
  else Ok (x /. y)

let calculate operation x y =
  match operation with
  | "add" -> Ok (add x y)
  | "subtract" -> Ok (subtract x y)
  | "multiply" -> Ok (multiply x y)
  | "divide" -> divide x y
  | _ -> Error "Error: Invalid operation"
```