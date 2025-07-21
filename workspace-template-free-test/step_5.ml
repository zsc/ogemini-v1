```ocaml
type t = {
  secret: int;
  attempts: int;
}

let create secret = {
  secret = secret;
  attempts = 0;
}

let guess game guess_number =
  if game.secret = guess_number then
    ({game with attempts = game.attempts + 1}, "You guessed it!")
  else if game.secret > guess_number then
    ({game with attempts = game.attempts + 1}, "Too low!")
  else
    ({game with attempts = game.attempts + 1}, "Too high!")
```