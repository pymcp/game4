## SaveManager
##
## Autoload providing save-slot constants and the save_completed signal.
## Actual snapshot/apply lives on `SaveGame`; autosave/region-save will be
## wired in a later phase via `attach_world()`.
extends Node

const AUTOSAVE_INTERVAL_SEC: float = 300.0
const DEFAULT_SLOT: String = "slot0"

signal save_completed(slot)

var current_slot: String = DEFAULT_SLOT
