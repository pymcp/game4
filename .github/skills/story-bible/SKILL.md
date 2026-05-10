---
name: story-bible
description: Use when writing quests, dialogue, NPC interactions, lore text, or any content that must be consistent with the game's narrative. Provides canonical story facts and player knowledge-state rules.
---

# Skill: Story Bible

Full detail lives in [docs/story.md](../../../docs/story.md). Read it before writing any quest or dialogue. This skill is a quick-reference summary.

---

## The Premise in One Paragraph

A microscopic crystalline particle called **Null** falls from space and accumulates harmlessly in moonstone ore under normal conditions. Thousands of years ago a civilization called the **Aetherians** learned to refine Null into fuel for a portal network called **fold-gates**. Their **Null Refineries** were sealed after their civilization collapsed, but have been leaking concentrated Null into the world's moonstone seams ever since. That contamination is the source of the spreading sickness — aggressive wildlife, tainted groundwater, dying livestock — that the player encounters from the first moments of the game.

---

## Chapter Map

| # | Title | Status | Core Question |
|---|---|---|---|
| 1 | The Quiet Sickness | **Implemented** | What is making the animals sick in this valley? |
| 2 | The Vein Runs Deeper | Planned | How far does the contamination spread, and where does it come from? |
| 3 | The Far Shore | Planned | Who built the ruins on the eastern islands, and what is the gate? |
| 4 | The Fold | Planned | What is the space between the gates, and what happened to the Aetherians? |
| 5 | The Null Refineries | Planned | How do we shut down the source permanently? |
| E | The Long Mending | Planned | Epilogue — recovery begins. |

---

## Player Knowledge State (Critical for Dialogue)

Never write dialogue or lore that gives the player information they haven't earned yet.

| Chapter | What the player knows |
|---|---|
| 1 | There is a sickness. It seems connected to the old mine. The ore has a strange dark residue. |
| 2 | The contamination is continental, not local. It follows moonstone deposits. Strange rune markers cluster near affected areas. |
| 3 | An ancient civilization built the ruins and the fold-gate. The rune markers were their navigation aids. |
| 4 | The Aetherians built fold-gates powered by Null. Their refineries collapsed. The leak has been running for centuries. |
| 5 | The full picture. Player can now read Aetherian script and negotiate with the central AI. |

---

## Key Facts — Never Contradict These

- **Null** is the contaminant. It is not magic in origin — it is a space particle concentrated by Aetherian technology.
- **Moonstone ore** is the vector. Null accumulates in it naturally; the refineries made it catastrophic.
- **The Aetherians** are extinct. No living person knows who they were at the start of the game. The Scholar NPC learns progressively through chapters 2–4.
- **Rune markers** already exist procedurally in every land region. Canonically they are Aetherian waypoints near fold-gate sites. The glowing ones near the coast (chapter 2) indicate a nearly-active gate.
- **The corrupted golem** in chapter 1's mine is an Aetherian construct — the player does not know this in chapter 1.
- **Mara's remedy** treats symptoms only. It cannot clear Null from the seams. Recovery requires shutting down the refineries (chapter 5).
- **The Fold** is not a world — it is the transit space between paired gates. Short exposure causes disorientation; lingering is fatal.

---

## Null — Quick Rules

| Context | Null behaviour |
|---|---|
| Open air | Disperses harmlessly. Not a direct hazard at natural density. |
| In moonstone seams | Accumulates slowly. Leak from refineries makes concentration catastrophic. |
| In groundwater | Causes sickness in wildlife and livestock; mild nausea in humans over months. |
| In the Fold | Fully visible, luminous particles. High density. Brief exposure: disorientation. Long: fatal. |
| After refineries shut down | Stops entering seams. Existing Null disperses over years, not overnight. |

---

## Continuity Checklist

Before finalising any quest, dialogue, or lore text:

- [ ] Does the local sickness symptom fit the Null model? (aggression, contaminated water, refusal to eat)
- [ ] Is the player's knowledge state correct for this chapter? (see table above)
- [ ] Do any NPCs claim knowledge of the Aetherians or Null that they shouldn't have?
- [ ] If a new Aetherian artifact or location is introduced, has it been added to `docs/story.md`?
- [ ] Do rune markers in the region make sense as Aetherian waypoints near a gate site?
