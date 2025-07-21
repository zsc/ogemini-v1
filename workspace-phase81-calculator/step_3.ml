```ocaml
(* step_3.ml *)

(* Define types for calculator operations *)
type operation =
  | Add of float
  | Subtract of float
  | Multiply of float
  | Clear

(* Define the calculator state *)
type calculator_state = {
  result : float;
}

(* Initial calculator state *)
let initial_state = { result = 0.0 }

(* Apply an operation to the calculator state *)
let apply_operation state operation =
  match operation with
  | Add x -> { result = state.result +. x }
  | Subtract x -> { result = state.result -. x }
  | Multiply x -> { result = state.result *. x }
  | Clear -> { result = 0.0 }

(* Get the current result from the calculator state *)
let get_result state = state.result
```