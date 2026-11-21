class_name Block
extends CSGBox3D
## A barrier across the full width of a Section, too tall to jump over, which the Runner must
## Mantle onto. Its top must be above jump height and within Mantle reach of it, unless it is
## reached from a Wall-run.

## True for a Block the Runner can only Mantle onto out of a Wall-run along a wall that ends at
## its face: its top must be beyond Mantle reach of jump height, and within Mantle reach of the
## Wall-run.
@export var from_wall_run := false
