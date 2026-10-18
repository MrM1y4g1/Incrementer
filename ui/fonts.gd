class_name Fonts
extends RefCounted
## The three typefaces from the art direction, all under the SIL Open Font License (see assets/fonts):
## Barlow Semi Condensed for labels and buttons, IBM Plex Mono for numbers in lists,
## and Oxanium for big readouts such as the Count.
## The font files are cached by Godot's resource loader; the variations are small and made per call.


static func body() -> Font:
	return load("res://assets/fonts/BarlowSemiCondensed-Medium.ttf")


## Spaced capitals for section headings such as "REGISTER · 8-BIT".
static func heading() -> Font:
	var variation := FontVariation.new()
	variation.base_font = load("res://assets/fonts/BarlowSemiCondensed-SemiBold.ttf")
	variation.spacing_glyph = 1
	return variation


static func mono() -> Font:
	return load("res://assets/fonts/IBMPlexMono-Regular.ttf")


static func readout() -> Font:
	var variation := FontVariation.new()
	variation.base_font = load("res://assets/fonts/Oxanium-Variable.ttf")
	variation.variation_opentype = {"weight": 600}
	return variation
