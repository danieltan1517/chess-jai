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
* AI Estimated Rating: 2700 (based on playing chess.com bots)
* Aspiration Window Search
* Parse and load FEN strings
* Iterative Deepening
* Internal Iterative Deepening
* Implements UCI (Universal Chess Interface) Protocol to communicate with a UI
* Legal move generation and detection
* Magic Bitboards
* Kogge-Stone Algorithm
* Passes all perft tests
* Implements Bitboards for fast move generation
* Move generator can generate approximately 65 million positions per second
* Uses https://github.com/dshawul/nnue-probe for NNUE (Efficiently Updatable Neural Networks) for chess evaluation function
* Negamax search with Alpha-Beta Pruning
* Encodes Moves as 16-bit integers
* Move Ordering
* Principle Variation Move Ordering
* MVV-LVA (Most Valuable Victim, Least Valuable Attacker) Implementation
* Hash Move
* Killer Moves Move Ordering
* History Moves Move Ordering
* Zobrist Hashing
* Transposition Table 
* 3-fold repetition & fifty-move rule (still some bugs.)
* Late Move Reduction
* Null Move Pruning 
* Reverse Futility Pruning/Static Move Pruning
* Razoring
* Simple Mop-Up Endgame Evaluation.
* Countermove Heuristic
* Mate Distance Pruning

## Still needs to be implemented
* NNUE Incremental Update: https://www.talkchess.com/forum3/viewtopic.php?f=7&t=75415&start=3

## Some articles to read: 
* https://www.codeproject.com/Articles/5313417/Worlds-fastest-Bitboard-Chess-Movegenerator
