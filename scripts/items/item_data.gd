class_name ItemData
extends Resource
## Data-only definition of a flying item. The FlyingItem scene is generic;
## everything that makes a puri a puri lives in a .tres file using this
## schema. New item types = new data files, no new code.

enum Kind {
	PURI,     ## Catch it — fills the plate
	CHILI,    ## Hazard — burns the plate, angers the stall
	FLY,      ## Hazard — disgusts the customer (used with the queue system)
	SPECIAL,  ## Power-up items (golden puri etc., later)
}

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.PURI
@export var color: Color = Color.WHITE
## Base score awarded when caught (before the streak multiplier).
@export var points: int = 10
## Relative spawn chance — higher is more common.
@export var spawn_weight: float = 1.0
## Silhouette polygon. Empty = default round-ish shape.
@export var shape: PackedVector2Array = PackedVector2Array()


func is_hazard() -> bool:
	return kind == Kind.CHILI or kind == Kind.FLY
