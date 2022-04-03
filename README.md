# Jai-Chess AI with User Interface

This Jai-Chess AI is a hobby project designed to test out and find bugs with the Jai Compiler.

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
* Parse and load FEN strings
* Uses https://github.com/Destaq/chess_graph/blob/master/elo_reading/openings_sheet.csv for opening book
* Opening Book (need to clean up memory usage)
* Engine vs. Engine Implemented (e.g. Stockfish vs Komodo)
* Multi-engine support
* Console command-line

## AI Chess Engine Features
* Estimated AI Rating: 3000 
* Supports UCI protocol
* Parse and load FEN strings

### Board Representation
* 8x8 Board
* Bitboards with Little Endian Rank-File Mapping
* Magic bitboards
* Kogge-Stone Algorithm
* Move generator generates 210 million positions per second
* Moves encoded as 16-bit integers
* Legal/Psuedo Legal Move Generation
* Staged Move Generation

### Search, Extensions Pruning
* Iterative Deepening
* Aspiration Window Search
* Internal Iterative Deepening
* Negamax search with Alpha-Beta Pruning
* Principle Variation Search
* SEE Quiescene Search Pruning
* Prob Cut
* Late Move Reduction/Pruning
* Null Move Pruning w/ Verification
* Reverse Futility Pruning/Static Move Pruning
* Razoring
* Mate Distance Pruning
* History Leaf Pruning
* Singular Search Extensions
* Check Extensions
* Recapture Extensions

### Transposition Table
* 3-fold repetition & fifty-move rule (still some bugs.)
* Zobrist Hashing w/ Incremental Update
* Prefetch Transposition Table Entries
* Aging

### Move Ordering
* MVV-LVA (Most Valuable Victim, Least Valuable Attacker) Implementation
* Transposition Table Hash Move
* Killer Moves Move Ordering
* History Moves Move Ordering
* Countermove Heuristic
* Follow Up Heuristic
* Relative History Move Ordering

### Evaluation
* Efficiently Updatable Neural Networks with Incremental Update
* Simple Mop-Up Endgame Evaluation.

## Still needs to be implemented
* UCI not fully supported 
* Check out [NNUE-pytorch](https://github.com/glinscott/nnue-pytorch/blob/master/docs/nnue.md)
