## Boat
##
## Top-down boat: docks on a water cell that is adjacent to land. When a
## nearby player interacts with it, the player boards and the boat tracks
## the player's position. While sailing, the player can only enter water
## cells (PlayerController flips its walkability rule). Interact again to
## disembark — the boat snaps back to its dock cell and the player is
## restored to a walkable land cell next to current position.
##
## Rendered programmatically as a small wooden hull (Polygon2D) so we
## don't depend on a specific sheet cell.
extends Node2D
class_name Boat

## Cell (in tile coords) the boat returns to when undocked.
var dock_cell: Vector2i = Vector2i.ZERO
## Player currently sailing this boat, or null when docked.
var sailor: PlayerController = null


func _ready() -> void:
	_build_visual()


## Called by PlayerController when interact pressed within range.
func interact(player: PlayerController) -> bool:
	if sailor == null:
		sailor = player
		player.start_sailing(self)
		return true
	if sailor == player:
		# Leave the boat where it currently sits so the player can re-board
		# from the same spot. Snap to tile centre and update `dock_cell`.
		var cell := Vector2i(
			int(floor(position.x / float(WorldConst.TILE_PX))),
			int(floor(position.y / float(WorldConst.TILE_PX))),
		)
		dock_cell = cell
		position = (Vector2(cell) + Vector2(0.5, 0.5)) * float(WorldConst.TILE_PX)
		player.stop_sailing(self)
		sailor = null
		return true
	return false


func _process(_delta: float) -> void:
	if sailor != null:
		position = sailor.position


func _build_visual() -> void:
	# Hull: brown trapezoid 12 wide x 6 tall, centred at origin.
	var hull := Polygon2D.new()
	hull.color = Color(0.45, 0.27, 0.13)
	hull.polygon = PackedVector2Array([
		Vector2(-6, -2), Vector2(6, -2),
		Vector2(4, 3), Vector2(-4, 3),
	])
	add_child(hull)
	# Plank deck on top.
	var deck := Polygon2D.new()
	deck.color = Color(0.62, 0.42, 0.22)
	deck.polygon = PackedVector2Array([
		Vector2(-5, -2), Vector2(5, -2),
		Vector2(5, -1), Vector2(-5, -1),
	])
	add_child(deck)
