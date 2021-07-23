# Jai-Chess AI and UI

This Jai-Chess AI is a hobby project I created for fun. Here is a list of the features inside this simple chess engine.

## User Interface Features

* Drag and drop behavior to move pieces
* Click to move pieces
* Legal move generation and detection
* Flip the board using the `X` Key
* Undo move using the `Ctrl+Z`Key
* Implements UCI (Universal Chess Interface) Protocol to communicate with any UCI compatible chess engine (e.g. Stockfish, RubiChess)
* Can do Human vs Computer, Computer vs Human, Human vs Human, and Computer vs Computer.
* Parse and load FEN strings

## AI Chess Engine Features
* AI Estimated Rating: 1590
* Parse and load FEN strings
* Iterative Deepening
* Implements UCI (Universal Chess Interface) Protocol to communicate with a UI
* Legal move generation and detection
* Passes all perft tests
* Implements Bitboards for fast move generation
* Move generator can generate approximately 24 million positions per second
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

## Still needs to be implemented
* Better optimization for negamax search
* Endgame evaluation
* 3-fold repetition detection
