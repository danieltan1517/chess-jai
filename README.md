# Chess Engine in Jai

This Chess Engine in Jai is a hobby project designed to find bugs and benchmark the Jai Compiler.
You can find video demos of this Chess Engine [here](https://www.youtube.com/watch?v=2OvE0I_rdpI&list=PL2fmKE0pL4IyET-eKbbBPw_i9IHN1QmFZ&index=1) 

## How to Build:
This project includes both a Chess Graphical User Interface and a UCI compatible Chess Engine.

Type `jai build.jai` to build both the UI and AI on `release` mode

Type `jai build.jai - ui` to build the GUI.

Type `jai build.jai - ai` to build the AI.

Type `jai build.jai - ui ai` to build both the GUI and the AI.

Type `jai build.jai - release` to build an optimized build.

Type `jai build.jai - release ai nnue_probe` to build the engine using Daniel Shawul's NNUE-Probe library. This C library is entirely optional, and is used to provide the best SIMD code for unsupported computers (e.g. AVX512, ARM NEON, MMX, etc.)

The build script will try to detect the CPU you are using, and pick either `AVX2`, `SSE`, or `cpu` automatically based on your processor. Send the flags `avx2`, `sse`, or `cpu` to manually toggle what you want. `cpu` means running with no SIMD support. Because Neural Networks are based on matrix multiplication, SIMD is needed to obtain the best performance.

## Code Organization
This code is divided up into the following files:
* `build.jai` is a build script for both the User Interface and GUI.
* `eval.jai` contains chess evaluation parameters
* `movegen.jai` contains the `Chess` structs and Piece definitions
* `search.jai` is the main `Chess` search function. This file contains code for Multi-threaded Parallel Search
* `uci.jai` contains the `main` function for the AI. This file parses the Universal Chess Interface protocol for the engine
* `ui.jai` is the `main` function for the UI. This file handles the User Interface with `Simp` and `GetRect`
* `linux.jai` is code specific to the Linux OS.
* `windows.jai` is code specific to the Windows OS.
* `macos.jai` is code specific to Mac OS.
* the `resources` contains the following information
  * Fonts
  * Sound Effects
  * Chess Piece Picture
  * Neural Network Model for AI
* The Efficiently Updatable Neural Network Code is organized as follows:
  * `nnue_avx2.jai` contains code for AVX2 processors.
  * `nnue_sse.jai` contains code for SSE processors.
  * `nnue_probe.jai` contains code for interacting with the NNUE-Probe C library by Daniel Shawul. This can be used to get the best optimization for SIMD architectures unsupported by the existing Jai code (e.g. AVX512 SIMD, ARM NEON SIMD, X86-64 MMX SIMD, etc.)
  * `nnue_cpu.jai` is a default code with no SIMD. Because it is general with no SIMD whatsoever, this allows someone to run it on any platform.

## User Interface Features

* Drag and drop behavior to move pieces
* Click to move pieces
* Legal move generation and detection
* Flip the board using the `X` Key
* New game using the `Ctrl+N` Key
* Undo move using the `Ctrl+Z`Key
* Redo move using the `Ctrl+Y`Key
* Implements UCI (Universal Chess Interface) Protocol to communicate with any UCI compatible chess engine (e.g. Stockfish, RubiChess)
* Can do Human vs Computer, Computer vs Human, Human vs Human, and Computer vs Computer.
* Parse and Loads FEN strings
* Engine vs. Engine Implemented (e.g. Stockfish vs Komodo)
* Multi-engine support
* UCI Engine Options
* Console command-line
* Windows, Mac, and Linux support
* Chess Clock with Increment
* Blindfold Mode
* Highlight Squares with Right Click
* Draw Arrows on the Board with Right Click
* Display Engine Lines
* Dark Background/Light Background Theme

## Chess Engine in Jai
* Estimated elo: 3100 
* UCI protocol

### Chess Engine Options
* Clear Hash - clears out the transposition table
* Transposition Table Memory Size (in MB). - adjusts the size of the transposition table in megabytes
* Number of Threads - adjusts the number of threads used by the CPU. increasing the number of threads should increase the playing strength of the CPU
* Multiple Principle Variation Lines - detects multiple PV lines. Set the PV to 1 for the best playing strength (the default)
* Difficulty Levels 1 to 8 - adjusts the difficulty of the engine.

### Parallel Search
* Lazy Shared Memory Processing Parallel Search
* Uses the `Thread_Group` Jai Module to implement threading

### Board Representation
* 8x8 Board
* Legal/Psuedo Legal Move Generation
* Staged Move Generation
* Bitboards with Little Endian Rank-File Mapping
* Fancy Magic Bitboards with Parallel Bit Extract
* Kogge-Stone Algorithm
* Move generator generates 324 million positions per second
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
* 16-byte Transposition Table Hash Entries
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
* Simple Mop-Up Endgame Evaluation
* NNUE Stockfish 12 HalfKP Architecture
* Supports the following CPU Architectures:
  * AVX2
  * SSE 
  * CPU w/o SIMD

### Credits
* Thank you to Jai Beta Users Patrik Smělý and Don Swet (github.com/cookednick) for testing the Chess program on Mac OS.
* Thank you to Maksim Korzh, author of the BBC chess engine. His work provided the main inspiration for this project. Here is a link to the [BBC Chess Engine](https://github.com/maksimKorzh/bbc).
* Thank you to Daniel Shawul for translating Stockfish NNUE into C. His work was the basis for my NNUE implementation. [nnue-probe](https://github.com/dshawul/nnue-probe)
* Thank you to Jonathan Blow, for allowing me access to the Jai Compiler Beta. [Jai-Community-Wiki](https://github.com/Jai-Community/Jai-Community-Library)
* [Berserk Chess Engine](https://github.com/jhonnold/berserk) was a great chess engine I learned a lot from. The code is well-organized and well-written. I highly recommend looking through Jay Honnold's work if you want to learn how to take your chess engine to the next level.
* [The Stockfish PyTorch NNUE Guide](https://github.com/glinscott/nnue-pytorch/blob/master/docs/nnue.md) is an incredibly detailed look at how NNUE works. I recommend reading it over and over again to get a full grasp about what is going on.

