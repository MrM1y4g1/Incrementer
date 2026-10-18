extends Node
## Global signals. Systems emit here; the UI and future audio listen.
## Keep payloads to plain values so listeners never hold on to game state.

@warning_ignore("unused_signal")
signal layer_bought(index: int, count: int)

@warning_ignore("unused_signal")
signal register_widened(bits: int)
