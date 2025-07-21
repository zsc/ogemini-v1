```ocaml
let () =
  print_string "Enter your name: ";
  flush stdout;
  let name = input_line stdin in
  Printf.printf "Hello, %s!\n" name
```