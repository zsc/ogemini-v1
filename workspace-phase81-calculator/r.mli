```ocaml
val add : float -> float -> float
(** [add x y] returns the sum of [x] and [y]. *)

val subtract : float -> float -> float
(** [subtract x y] returns the difference of [x] and [y]. *)

val multiply : float -> float -> float
(** [multiply x y] returns the product of [x] and [y]. *)

val divide : float -> float -> float
(** [divide x y] returns the quotient of [x] and [y].
    Raises [Division_by_zero] if [y] is 0.0. *)

val calculate : string -> float -> float -> (float, string) result
(** [calculate op x y] performs the operation [op] on [x] and [y].
    [op] can be "+", "-", "*", or "/".
    Returns [Ok result] if the operation is successful,
    or [Error message] if the operation is invalid or division by zero occurs. *)
```