# Jai-Chess AI and UI

This Jai-Chess AI is a hobby project I created for fun. Here is a list of the features inside this simple chess engine.

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
* Estimated AI Rating: 2700
* Supports UCI protocol
* Parse and load FEN strings

### Board Representation
* 8x8 Board
* Bitboards with Little Endian Rank-File Mapping
* Magic bitboards
* Kogge-Stone Algorithm
* Move generator can generate 55 million positions per second
* Moves represented as 16-bit integers

### Search and Pruning
* Iterative Deepening
* Aspiration Window Search
* Internal Iterative Deepening
* Negamax search with Alpha-Beta Pruning
* Principle Variation Search
* SEE Quiescene Search Pruning
* Late Move Reduction
* Null Move Pruning 
* Reverse Futility Pruning/Static Move Pruning
* Razoring
* Mate Distance Pruning

### Transposition Table
* 3-fold repetition & fifty-move rule (still some bugs.)
* Zobrist Hashing w/ Incremental Update

### Move Ordering
* MVV-LVA (Most Valuable Victim, Least Valuable Attacker) Implementation
* Transposition Table Hash Move
* Killer Moves Move Ordering
* History Moves Move Ordering
* Countermove Heuristic
* Follow Up Heuristic

### Evaluation
* [NNUE](https://github.com/dshawul/nnue-probe) (Efficiently Updatable Neural Networks) for chess evaluation function
* Simple Mop-Up Endgame Evaluation.

## Still needs to be implemented
* Better History Move Ordering
* NNUE Incremental Update: https://www.talkchess.com/forum3/viewtopic.php?f=7&t=75415&start=3
* UCI not fully supported 
* Check out Berserk Chess Engine. [Berserk](https://github.com/jhonnold/berserk)
* Check out [NNUE-pytorch](https://github.com/glinscott/nnue-pytorch/blob/master/docs/nnue.md)
