(* Test file for edit and search tools *)
let hello_world () =
  print_endline "Hello, OCaml World!"

let add x y = x + y

let multiply x y = x * y

let main () =
  hello_world ();
  let result = add 2 3 in
  Printf.printf "2 + 3 = %d\n" result;
  let product = multiply 4 5 in
  Printf.printf "4 * 5 = %d\n" product