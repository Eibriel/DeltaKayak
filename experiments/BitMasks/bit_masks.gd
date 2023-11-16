extends Node

var masks:PackedByteArray

const FROZEN = 0b1000
const BURNING = 0b0100
const MUDDED = 0b0010
const ELECTROCUTED = 0b0001

func _ready():
	masks.append(0b000)
	masks[0] |= FROZEN + BURNING
	
	# Check if frozen
	if masks[0] & FROZEN:
		print("FROZEN")
	
	# Check if burning
	if masks[0] & BURNING:
		print("BURNING")
	
	# Disable frozen
	masks[0] &= ~FROZEN
	# Check if frozen
	if not masks[0] & FROZEN:
		print("NOT FROZEN")

func is_bit_enabled(mask, index):
	return mask & (1 << index) != 0

func enable_bit(mask, index):
	return mask | (1 << index)

func disable_bit(mask, index):
	return mask & ~(1 << index)
