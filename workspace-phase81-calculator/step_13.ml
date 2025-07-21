```ocaml
module R = struct
  type result = (float, string) Result.t

  let add x y = x +. y

  let subtract x y = x -. y

  let multiply x y = x *. y

  let divide x y =
    if y = 0.0 then
      Error "Division by zero"
    else
      Ok (x /. y)

  let clear _ = 0.0
end
```