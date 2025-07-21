```ocaml
type t = {
  secret : int;
  attempts : int;
}

let create secret = { secret; attempts = 0 }

let guess t attempt =
  let attempts = t.attempts + 1 in
  if attempt = t.secret then
    ({ t with attempts }, "You guessed it!")
  else if attempt < t.secret then
    ({ t with attempts }, "Too low!")
  else
    ({ t with attempts }, "Too high!")
```