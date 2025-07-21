```ocaml
type comparison =
  | Higher
  | Lower
  | Correct

type t = {
  secret_number : int;
  guess : int;
  is_valid : bool;
  comparison_result : comparison option;
}

let create secret_number =
  { secret_number; guess = 0; is_valid = false; comparison_result = None }

let update t guess =
  if guess < 1 || guess > 100 then
    { t with guess; is_valid = false; comparison_result = None }
  else
    let comparison_result =
      if guess > t.secret_number then Some Higher
      else if guess < t.secret_number then Some Lower
      else Some Correct
    in
    { t with guess; is_valid = true; comparison_result }

let feedback t =
  match t.comparison_result with
  | Some Higher -> "Too high!"
  | Some Lower -> "Too low!"
  | Some Correct -> "Correct!"
  | None -> "Invalid guess. Please enter a number between 1 and 100."

let is_won t =
  match t.comparison_result with
  | Some Correct -> true
  | _ -> false
```