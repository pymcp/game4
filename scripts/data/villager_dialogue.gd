## VillagerDialogue
##
## Static pool of one-liners for peaceful villager NPCs. The current set
## is themed around the rumored animal sickness spreading through the
## land — we'll grow this into proper dialogue trees later, but for now
## one line per villager (deterministic by seed) is enough to make the
## world feel populated.
##
## Pure data + lookup; no scene, no node.
class_name VillagerDialogue
extends RefCounted

const LINES: Array[String] = [
	"Have you seen the sheep? They've been off their feed all week.",
	"My old hound just lays there now. Won't even bark at the post-runner.",
	"Three of my chickens dropped dead this morning. Three!",
	"They say it started up in the hill country. I don't believe it.",
	"The herbalist's been sold out of fennel root since the new moon.",
	"I won't drink the well water until somebody figures this out.",
	"My brother's pigs got it. He had to burn the lot of them.",
	"It's a punishment, mark my words. We've been careless.",
	"Don't pet the strays. Don't even look at them too long.",
	"The priest is calling it the Quiet Sickness. Cattle just… stop.",
	"I caught a rabbit yesterday and its eyes were all milky. Threw it back.",
	"Be careful out there, traveller. Whatever this is, it's spreading.",
]


## Returns the line a villager with the given seed should always say.
## Same seed → same line, every time, so each villager has a stable
## "personality" until we wire up real dialogue trees.
static func pick_line(npc_seed: int) -> String:
	if LINES.is_empty():
		return ""
	var n: int = LINES.size()
	return LINES[((npc_seed % n) + n) % n]


## Deterministic display name from a seed. Tiny pool for now.
const _NAMES: Array[String] = [
	"Eda", "Bram", "Tilda", "Ren", "Mara", "Oswin",
	"Ines", "Cael", "Junia", "Pell", "Wren", "Hask",
]

static func pick_name(npc_seed: int) -> String:
	var n: int = _NAMES.size()
	return _NAMES[((npc_seed / 13) % n + n) % n]
