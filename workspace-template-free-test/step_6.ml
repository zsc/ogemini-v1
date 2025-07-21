```ocaml
(* step_6.ml *)

(* Types for the game state and guess attempts *)
type game_state = {
  secret_word : string;
  max_attempts : int;
  mutable attempts_left : int;
  mutable guessed_letters : char list;
  mutable game_over : bool;
  mutable has_won : bool;
}

type guess_result =
  | Correct
  | Incorrect
  | AlreadyGuessed
  | GameOver
  | Win

(* Function to create a new game state *)
let new_game secret_word max_attempts =
  {
    secret_word;
    max_attempts;
    attempts_left = max_attempts;
    guessed_letters = [];
    game_over = false;
    has_won = false;
  }

(* Function to process a guess *)
let guess game attempt =
  if game.game_over then GameOver
  else
    let attempt_char =
      match attempt with
      | "" ->
          print_endline "No input provided. Please enter a letter.";
          ' ' (* Dummy character *)
      | s -> String.get s 0
    in

    if List.mem attempt_char game.guessed_letters then AlreadyGuessed
    else (
      game.guessed_letters <- attempt_char :: game.guessed_letters;

      if String.contains game.secret_word attempt_char then (
        (* Check if the player has won *)
        let all_letters_guessed =
          String.to_seq game.secret_word
          |> Seq.for_all (fun c -> List.mem c game.guessed_letters)
        in

        if all_letters_guessed then (
          game.game_over <- true;
          game.has_won <- true;
          Win
        ) else
          Correct
      ) else (
        game.attempts_left <- game.attempts_left - 1;

        if game.attempts_left = 0 then (
          game.game_over <- true;
          game.has_won <- false;
          GameOver
        ) else
          Incorrect
      )
    )

(* Helper function to display the current game state *)
let display_game_state game =
  let masked_word =
    String.map
      (fun c ->
        if List.mem c game.guessed_letters then c else '_')
      game.secret_word
  in
  Printf.printf "Word: %s\n" masked_word;
  Printf.printf "Attempts left: %d\n" game.attempts_left;
  Printf.printf "Guessed letters: %s\n"
    (String.of_seq (List.to_seq game.guessed_letters));
  Printf.printf "Game Over: %b\n" game.game_over;
  Printf.printf "Has Won: %b\n" game.has_won

(* Example usage (for testing) *)
let () =
  let game = new_game "example" 6 in
  display_game_state game;

  let result1 = guess game "e" in
  Printf.printf "Guess 'e': %s\n"
    (match result1 with
     | Correct -> "Correct"
     | Incorrect -> "Incorrect"
     | AlreadyGuessed -> "Already Guessed"
     | GameOver -> "Game Over"
     | Win -> "Win");
  display_game_state game;

  let result2 = guess game "x" in
  Printf.printf "Guess 'x': %s\n"
    (match result2 with
     | Correct -> "Correct"
     | Incorrect -> "Incorrect"
     | AlreadyGuessed -> "Already Guessed"
     | GameOver -> "Game Over"
     | Win -> "Win");
  display_game_state game;

  let result3 = guess game "m" in
  Printf.printf "Guess 'm': %s\n"
    (match result3 with
     | Correct -> "Correct"
     | Incorrect -> "Incorrect"
     | AlreadyGuessed -> "Already Guessed"
     | GameOver -> "Game Over"
     | Win -> "Win");
  display_game_state game;

  let result4 = guess game "p" in
  Printf.printf "Guess 'p': %s\n"
    (match result4 with
     | Correct -> "Correct"
     | Incorrect -> "Incorrect"
     | AlreadyGuessed -> "Already Guessed"
     | GameOver -> "Game Over"
     | Win -> "Win");
  display_game_state game;

  let result5 = guess game "l" in
  Printf.printf "Guess 'l': %s\n"
    (match result5 with
     | Correct -> "Correct"
     | Incorrect -> "Incorrect"
     | AlreadyGuessed -> "Already Guessed"
     | GameOver -> "Game Over"
     | Win -> "Win");
  display_game_state game;

  let result6 = guess game "a" in
  Printf.printf "Guess 'a': %s\n"
    (match result6 with
     | Correct -> "Correct"
     | Incorrect -> "Incorrect"
     | AlreadyGuessed -> "Already Guessed"
     | GameOver -> "Game Over"
     | Win -> "Win");
  display_game_state game;
```