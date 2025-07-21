```ocaml
type game_state = {
  secret : string;
  attempts : int;
  won : bool;
}

let check_attempt t attempt =
  if attempt = t.secret then
    ({ t with attempts = t.attempts + 1; won = true }, "Correct!")
  else
    ({ t with attempts = t.attempts + 1 }, "Incorrect!")

let create_game secret = { secret; attempts = 0; won = false }
```