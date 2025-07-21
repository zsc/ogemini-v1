```ocaml
type t = {
  mutable result : int;
}

let create () = { result = 0 }

let add t x =
  t.result <- t.result + x;
  t.result

let subtract t x =
  t.result <- t.result - x;
  t.result

let multiply t x =
  t.result <- t.result * x;
  t.result

let clear t =
  t.result <- 0;
  t.result

let get_result t = t.result
```