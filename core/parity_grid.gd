class_name ParityGrid
extends RefCounted
## The scrub puzzle for a bad bit: a square word of bits in which every row and every column should hold an
## even number of set bits. Some bits are flipped, each in a row and a column of its own, so that many rows
## and columns check out odd, and the flipped bits sit where they cross. Flip bits until every line checks
## out. The same seed always makes the same word.
##
## The puzzle grows with the register: wider registers come later in a run and later in the game, so they
## get bigger words with more flipped bits.

## Register width → [word size, flipped bits].
const LEVELS := {
	8: [4, 1], 16: [4, 1], 32: [5, 1], 64: [5, 2], 128: [6, 2], 256: [6, 3], 512: [7, 3], 1024: [7, 4],
}

var size := 4
## How many bits were flipped.
var flips := 1
## Row by row, 1 for a set bit.
var cells := PackedByteArray()


## The word size for a register of this width.
static func size_for(register_bits: int) -> int:
	return int(_level(register_bits)[0])


## How many bits are flipped in the puzzle for a register of this width.
static func flips_for(register_bits: int) -> int:
	return int(_level(register_bits)[1])


static func _level(register_bits: int) -> Array:
	var level: Array = LEVELS[8]
	for bits: int in LEVELS:
		if register_bits >= bits:
			level = LEVELS[bits]
	return level


static func make(grid_size: int, grid_seed: int, flip_count: int = 1) -> ParityGrid:
	var grid := ParityGrid.new()
	grid.size = grid_size
	grid.flips = clampi(flip_count, 1, grid_size)
	grid.cells.resize(grid_size * grid_size)
	var rng := RandomNumberGenerator.new()
	rng.seed = grid_seed
	var last := grid_size - 1
	# Random data, then a parity bit at the end of each row and a parity row at the bottom. The parity
	# row is even too, because it adds up the same bits as all the even rows above it.
	for row: int in last:
		var ones := 0
		for column: int in last:
			var bit := rng.randi_range(0, 1)
			grid.cells[row * grid_size + column] = bit
			ones += bit
		grid.cells[row * grid_size + last] = ones % 2
	for column: int in grid_size:
		var ones := 0
		for row: int in last:
			ones += grid.cells[row * grid_size + column]
		grid.cells[last * grid_size + column] = ones % 2
	# Each flip gets a row and a column no other flip uses, so every flip shows as an odd row and an odd column.
	var rows := _shuffled(grid_size, rng)
	var columns := _shuffled(grid_size, rng)
	for i: int in grid.flips:
		grid.flip(rows[i] * grid_size + columns[i])
	return grid


## 0 to count - 1 in a random order.
static func _shuffled(count: int, rng: RandomNumberGenerator) -> PackedInt32Array:
	var order := PackedInt32Array()
	for i: int in count:
		order.append(i)
	for i: int in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := order[i]
		order[i] = order[j]
		order[j] = swap
	return order


func flip(index: int) -> void:
	cells[index] = 1 - cells[index]


func bit_at(row: int, column: int) -> int:
	return cells[row * size + column]


func row_even(row: int) -> bool:
	var ones := 0
	for column: int in size:
		ones += bit_at(row, column)
	return ones % 2 == 0


func column_even(column: int) -> bool:
	var ones := 0
	for row: int in size:
		ones += bit_at(row, column)
	return ones % 2 == 0


func solved() -> bool:
	for i: int in size:
		if not row_even(i) or not column_even(i):
			return false
	return true
