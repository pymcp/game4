## PartyMemberDef
##
## Static description of one party member type. Loaded from
## `resources/party_members.json` by PartyMemberRegistry.
class_name PartyMemberDef
extends Resource

## Unique identifier matching the JSON key.
@export var id: StringName = &""
## Human-readable name shown in the CaravanMenu.
@export var display_name: String = ""
## Which crafting domain this member handles. Empty string = not a crafter.
@export var crafter_domain: StringName = &""
## Atlas cell [col, row] for portrait sprite. Set via SpritePicker.
@export var portrait_cell: Vector2i = Vector2i.ZERO
## If true, this member follows the player into dungeons/labyrinths.
@export var can_follow: bool = false
