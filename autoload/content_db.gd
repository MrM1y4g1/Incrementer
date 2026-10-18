extends Node
## Loads every content definition once at startup. Other code reads `ContentDB.layers`.

const LAYER_DIR := "res://data/layers"

var layers: Array[LayerDef] = []


func _init() -> void:
	layers = ContentLoader.load_layers(LAYER_DIR)
