extends Node
## Loads every content definition once at startup and checks it. Other code reads `ContentDB.content`.
## Broken content (duplicate ids, missing layers) stops a debug build with a clear error.

const ROOT := "res://data"

var content: Content


func _init() -> void:
	content = Content.load_from(ROOT)
	var errors := content.validate()
	for error: String in errors:
		push_error("Content: " + error)
	assert(errors.is_empty(), "res://data has %d content problems; see the errors above." % errors.size())
