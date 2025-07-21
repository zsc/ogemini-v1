(* OCaml translation of Python Calculator class *)

(* Define the calculator type *)
type calculator = { mutable result : int }

(* Function to create a new calculator *)
let create () = { result = 0 }

(* Function to add to the calculator's result *)
let add calc x =
  calc.result <- calc.result + x;
  calc.result

(* Function to subtract from the calculator's result *)
let subtract calc x =
  calc.result <- calc.result - x;
  calc.result

(* Function to multiply the calculator's result *)
let multiply calc x =
  calc.result <- calc.result * x;
  calc.result

(* Function to clear the calculator's result *)
let clear calc =
  calc.result <- 0;
  calc.result

(* Function to get the calculator's result *)
let get_result calc = calc.result

(* Example usage *)
let () =
  let calc = create () in
  Printf.printf "Initial: %d\n" (get_result calc);
  Printf.printf "Add 5: %d\n" (add calc 5);
  Printf.printf "Multiply by 3: %d\n" (multiply calc 3);
  Printf.printf "Subtract 2: %d\n" (subtract calc 2);
  Printf.printf "Result: %d\n" (get_result calc);
  Printf.printf "Clear: %d\n" (clear calc)