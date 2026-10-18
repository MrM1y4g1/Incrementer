extends Node
## Global signals. Systems emit here; the UI and future audio listen.
## Keep payloads to plain values so listeners never hold on to game state.

@warning_ignore("unused_signal")
signal layer_bought(index: int, count: int)

@warning_ignore("unused_signal")
signal register_widened(bits: int)

@warning_ignore("unused_signal")
signal upgrade_bought(id: StringName)

@warning_ignore("unused_signal")
signal clock_raised(level: int)

@warning_ignore("unused_signal")
signal achievement_unlocked(id: StringName)

@warning_ignore("unused_signal")
signal overflowed(carry: float)

@warning_ignore("unused_signal")
signal firmware_bought(id: StringName)

@warning_ignore("unused_signal")
signal game_ended
