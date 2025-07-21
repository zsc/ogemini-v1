```ocaml
let calculate operation x y =
  match operation with
  | "add" -> x +. y
  | "subtract" -> x -. y
  | "multiply" -> x *. y
  | "divide" -> if y = 0.0 then Float.infinity else x /. y
  | _ -> failwith "Invalid operation"

let () =
  let result = calculate "divide" 5.0 0.0 in
  Printf.printf "Result: %f\n" result
```