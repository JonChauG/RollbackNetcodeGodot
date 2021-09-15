# RollbackNetcodeGodot (OUTDATED)

# UPDATE: New code and tutorial series available
Repositories:

https://github.com/JonChauG/GodotRollbackNetcode-Part-1

https://github.com/JonChauG/GodotRollbackNetcode-Part-2

https://github.com/JonChauG/GodotRollbackNetcode-Part-3-FINAL (Please use the repository here instead of this one)

---

Tutorial Videos:

Part 1: Base Game and Saving Game States - https://www.youtube.com/watch?v=AOct7C422z8

Part 2: Delay-Based Netcode - https://www.youtube.com/watch?v=X55-gfqhQ_E

Part 3 (Final): Rollback Netcode - https://www.youtube.com/watch?v=sg1Q_71cjd8

---
Rollback netcode example for Godot.

Demo video: https://www.youtube.com/watch?v=CrqZW6EoGII


Many games use delay-based netcode in which games will block until they receive inputs from networked players that allow the game to proceed (to maintain synchronization between players). However, games may constantly block and delay in an imperfect network while they wait for needed inputs, making for an unpleasant experience.


With rollback netcode, if the game has not yet received needed inputs from the network, the game will continue on a temporary guessed input. When the game finally receives the actual input to replace the guess, the game will resimulate the game state to as if the actual input arrived "on time". Implementations that resimulate the game state in a single frame allow for an uninterrupted transition into the current "correct" game state. The player will see a sudden and abrupt visual adjustment, but this is usually a more pleasant experience than that of delay-based netcode.


In order to resimulate the game state, my implementation saves a state snapshot at every frame as a base to begin resimulation.* Given memory limitations and unpleasantness from visually extreme state corrections, it is practical to limit the amount of states saved at any given time and thus limit how far back in the past resimulation can begin from. As a result, rollback netcode (my implementation and those I've seen) blocks like delay-based netcode when the saved oldest game state has an unfulfilled guess input to be replaced by an actual input from the network.


Overall, compared to delay-based netcode, rollback netcode provides a larger time window for needed packets to arrive while maintaining a good player experience.


\*I save states at every frame for simplicity. I believe you only really need to save states on frames when inputs are guessed, but all player inputs should be saved on every frame until unneeded.
