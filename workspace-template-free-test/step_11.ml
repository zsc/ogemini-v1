```ocaml
type state = {
  attempts : int;
}

let update_attempts t =
  let attempts = t.attempts + 1 in
  { attempts }
```