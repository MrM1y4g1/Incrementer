class_name ParityGrid
extends RefCounted
## The scrub puzzle for a bad bit: a square word of bits in which every row and every column should hold an
## even number of set bits. One bit is flipped, so one row and one column check out odd, and the flipped bit
## sits where they cross. Flip bits until every line checks out. The same seed always makes the same word.

var size := 4
## Row by row, 1 for a set bit.
var cells := PackedByteArray()


## The puzzle for a bad bit: bigger words for higher bits.
static func size_for(bit: int) -> int:
	if bit < 128:
		return 4
	return 5 if bit < 512 else 6


static func make(grid_size: int, grid_seed: int) -> ParityGrid:
	var grid := ParityGrid.new()
	grid.size = grid_size
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
	grid.flip(rng.randi_range(0, grid_size * grid_size - 1))
	return grid


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
