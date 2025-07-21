```ocaml
(* /workspace/step_1.ml *)

(* Define the core types for the number guessing game *)

(* The range of numbers to guess from *)
type range = { min : int; max : int }

(* The game state *)
type game_state =
  | InProgress
  | Won
  | Lost

(* The main game record *)
type game = {
  secret_number : int;
  guess_range : range;
  attempts_remaining : int;
  state : game_state;
}

(* Function to create a new game *)
let new_game ~min ~max ~attempts : game =
  let secret_number = min + Random.int (max - min + 1) in
  {
    secret_number;
    guess_range = { min; max };
    attempts_remaining = attempts;
    state = InProgress;
  }

(* Function to process a guess *)
let process_guess game guess =
  match game.state with
  | InProgress ->
      if guess = game.secret_number then
        { game with state = Won }
      else if game.attempts_remaining = 1 then
        { game with state = Lost; attempts_remaining = 0 }
      else
        { game with attempts_remaining = game.attempts_remaining - 1 }
  | Won | Lost -> game

(* Function to get the game state *)
let get_game_state game = game.state

(* Function to get the remaining attempts *)
let get_attempts_remaining game = game.attempts_remaining

(* Function to get the guess range *)
let get_guess_range game = game.guess_range

(* Function to get the secret number (for debugging/testing only) *)
let get_secret_number game = game.secret_number
```