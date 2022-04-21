# Chess Engine in Jai

This Chess Engine in Jai is a hobby project designed to test out and find bugs with the Jai Compiler.

## How to Build:
Type `jai build.jai -- ui` to build the chess engine GUI.

Type `jai build.jai` to build the chess engine AI.

Type `jai build.jai -- release` to build the release build.

You need to download the NNUE library https://github.com/dshawul/nnue-probe to run the chess AI.

The chess GUI uses the glfw3 and gl libraries.

## User Interface Features

* Drag and drop behavior to move pieces
* Click to move pieces
* Legal move generation and detection
* Flip the board using the `X` Key
* Undo move using the `Ctrl+Z`Key
* New game using the `Ctrl+N` Key
* Implements UCI (Universal Chess Interface) Protocol to communicate with any UCI compatible chess engine (e.g. Stockfish, RubiChess)
* Can do Human vs Computer, Computer vs Human, Human vs Human, and Computer vs Computer.
* Parse and Loads FEN strings
* Engine vs. Engine Implemented (e.g. Stockfish vs Komodo)
* Multi-engine support
* Console command-line

## Chess Engine in Jai
* Estimated elo: 3000 
* UCI protocol

### Board Representation
* 8x8 Board
* Legal/Psuedo Legal Move Generation
* Staged Move Generation
* Bitboards with Little Endian Rank-File Mapping
* Magic Bitboards
* Kogge-Stone Algorithm
* Move generator generates 210 million positions per second
* Moves encoded as 16-bit integers

### Search
* Negamax Search with Alpha-Beta Pruning
* Principle Variation Search
* Iterative Deepening
* Aspiration Window Search
* Internal Iterative Deepening

### Pruning and Reductions
* Null Move Pruning w/ Verification
* Low Depth SEE Pruning
* Reverse Futility Pruning/Static Move Pruning
* Delta Pruning
* SEE Quiescene Search Pruning
* Razoring
* Mate Distance Pruning
* History Leaf Reduction/Pruning
* Prob Cut
* Late Move Reduction/Pruning

### Extensions
* Singular Search Extensions
* Check Extensions
* Recapture Extensions

### Transposition Table
* 16-bit Transposition Table Hash Entries
* 3-fold repetition & Fifty-move Rule
* Zobrist Hashing w/ Incremental Update
* Transposition Table Probing in Non PV Nodes
* Prefetch Transposition Table Entries
* Depth-Preferred Replacement Scheme
* Aging

### Move Ordering
* MVV-LVA (Most Valuable Victim, Least Valuable Attacker) Implementation
* Transposition Table Hash Move
* Killer Moves Move Ordering
* History Moves Move Ordering
* Tactical History Move Ordering
* Countermove and Follow Up History Move Ordering
* Relative History Move Ordering

### Evaluation
* Efficiently Updatable Neural Networks with Incremental Update
* Simple Mop-Up Endgame Evaluation.

## Still needs to be implemented
* verify is_legal functions correctly
* UCI not fully supported 
* Check out [NNUE-pytorch](https://github.com/glinscott/nnue-pytorch/blob/master/docs/nnue.md)
