# OCaml 2048 Bit-Level Implementation Specification

## Goal
Translate the Python 2048 game to OCaml with 100% bit-level accuracy and mathematical equivalence.

## Core Requirements

### 1. Data Structures
```ocaml
type board = int64  (* 64-bit board representation *)
type row = int      (* 16-bit row representation *)
```

### 2. Essential Functions (MUST implement ALL)

#### Bit Manipulation Core
```ocaml
val int_to_row : int -> int list              (* Convert 16-bit int to 4-element list *)
val row_to_int : int list -> int              (* Convert 4-element list to 16-bit int *)
val get_tile : board -> int -> int            (* Get tile value at position *)
val set_tile : board -> int -> int -> board   (* Set tile value at position *)
```

#### Lookup Table Generation (CRITICAL)
```ocaml
val move_row_left : int list -> int list * int      (* Core algorithm: move + merge + score *)
val init_tables : unit -> unit                     (* Generate all 65536 lookup entries *)
```

#### Game Logic
```ocaml
val move_left : board -> board * int * bool    (* Returns: new_board, score, moved_flag *)
val move_right : board -> board * int * bool
val move_up : board -> board * int * bool  
val move_down : board -> board * int * bool
val add_random_tile : board -> board
val reset_board : unit -> board
```

### 3. Mathematical Equivalence Tests

#### Must pass ALL these verification tests:
1. **Bit representation test**: Every board position maps identically
2. **Move operation test**: All 4 directions produce identical results
3. **Lookup table test**: All 65536 entries match Python exactly
4. **Score calculation test**: Points awarded must be identical
5. **Random tile test**: Same positions available, same values

### 4. Implementation Milestones

#### Phase 1: Basic Structure (Build Success)
- [ ] Create working dune project structure
- [ ] Define core types and empty function signatures
- [ ] Achieve successful `dune build` with stub implementations

#### Phase 2: Bit Operations (Core Logic)
- [ ] Implement `int_to_row` and `row_to_int` 
- [ ] Implement `get_tile` and `set_tile`
- [ ] Test bit manipulation accuracy vs Python

#### Phase 3: Game Algorithm (Move Logic)  
- [ ] Implement `move_row_left` algorithm
- [ ] Generate lookup tables for all 65536 combinations
- [ ] Implement directional moves using lookup tables

#### Phase 4: Integration (Complete Game)
- [ ] Add random tile generation
- [ ] Implement game state management  
- [ ] Create test suite for verification

#### Phase 5: Verification (Bit-Level Accuracy)
- [ ] Compare every operation against Python reference
- [ ] Ensure mathematical equivalence across all functions
- [ ] Generate comprehensive test report

## Key Implementation Notes

### Critical Python Algorithm Translation
```python
# Python: move_row_left algorithm
def move_row_left(row):
    nz = [x for x in row if x]           # Remove zeros
    merged, sc, i = [], 0, 0
    while i < len(nz):
        if i+1<len(nz) and nz[i]==nz[i+1]:   # Merge equal adjacent
            merged.append(nz[i]+1)
            sc += (1 << (nz[i]+1))           # Score = actual tile value
            i += 2
        else:
            merged.append(nz[i]); i += 1
    res = merged + [0]*(4-len(merged))       # Pad with zeros
    return res, sc
```

### OCaml Translation Requirements
- Use `Int64` module for 64-bit operations
- Pre-compute all lookup tables at startup
- Maintain identical bit patterns and mathematical operations
- Handle edge cases exactly as Python version

## Success Criteria

**Definition of Success**: 
- `dune build` succeeds with zero errors
- `dune exec main.exe` runs and plays 2048 game
- All verification tests pass with 100% mathematical accuracy
- Trace file shows autonomous agent completed all phases

**Definition of Failure**:
- Any compilation errors
- Mathematical discrepancies vs Python reference  
- Missing core functionality
- Agent unable to complete implementation autonomously