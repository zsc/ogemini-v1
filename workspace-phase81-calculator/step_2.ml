```ocaml
let add x y = x + y

let subtract x y = x - y

let multiply x y = x * y

let divide x y =
  if y = 0 then
    failwith "Error: Division by zero"
  else
    x / y

let calculate operation x y =
  match operation with
  | "add" -> add x y
  | "subtract" -> subtract x y
  | "multiply" -> multiply x y
  | "divide" -> divide x y
  | _ -> failwith "Error: Invalid operation"

let () =
  print_int (calculate "add" 5 3);
  print_newline ();
  print_int (calculate "divide" 10 2);
  print_newline ();
  try
    print_int (calculate "divide" 5 0);
    print_newline ();
  with
  | Failure msg -> Printf.printf "%s\n" msg
```