# Story Bible — *Fantasy Co-op*

> **Purpose:** Canonical reference for plot, world-building, NPCs, and quest design. When writing new quests, dialogue, or lore text, check here first. When something is established in-game, update this file.

---

## Setting

The world is a patchwork of island-like land masses separated by ocean, each region roughly a day's travel across. Wildlife — wolves, rats, deer, boar — is the primary indicator of the world's health. Villagers farm, fish, trade by boat, and live close to the land.

Beneath the ground, veins of **moonstone ore** run across the continent in deep mineral seams. Moonstone is semi-magical — it glows faintly, holds enchantments, and has been mined for centuries for tools and trinkets. Most people think nothing of it.

Thousands of years ago, a civilization called the **Aetherians** discovered that moonstone ore acts as a natural conductor for a substance they called **Null** — microscopic crystalline particles that fall from space as a faint, invisible rain. Null is inert in nature, but the Aetherians learned to concentrate and weaponize it. They built facilities called **Null Refineries** to harvest and process it. They also built a network of **fold-gates** — portals that compressed space — to move people and cargo across vast distances.

Then they vanished. Their gates went dark. Their refineries were sealed. Centuries passed and the world forgot them entirely.

But sealed does not mean inert. The refineries have been slowly leaking Null into the moonstone seams for centuries. The ore carries it upward through groundwater, and the sickness spreads — quietly, at first, then everywhere.

---

## The Illness

**Null-sickness** presents differently across species:
- **Wildlife:** aggression without cause, loss of fear, refusal to eat, death within weeks
- **Livestock:** listlessness, contaminated milk, eventual organ failure
- **Plants:** stunted growth, bitter taste, dark discoloration at roots
- **Groundwater:** faint mineral taste, causes mild nausea in humans over months
- **Humans:** long-term Null exposure causes memory fragmentation, fever, and in extreme cases crystalline growths on the skin — extremely rare at current contamination levels, but a foreshadowing of what is coming

The illness has no single obvious cause. Each village blames something local — bad seasons, cursed land, wolf packs. Only someone who travels widely enough would notice the pattern.

---

## The Aetherians (Ancient Civilization)

- **Who they were:** A highly advanced culture that mastered portal travel and material science. Not evil — curious, ambitious, ultimately reckless.
- **What they did:** Discovered Null falling from space and learned to refine it into a fuel source for their fold-gates. Built a global network of gates and dozens of Null Refineries to power them.
- **Why they vanished:** The leading theory (discoverable in Act 3) is that a critical refinery exploded during an experiment, sending a Null shockwave that destroyed much of their infrastructure and killed most of the population within months. Survivors scattered; knowledge was lost.
- **What they left behind:**
  - Rune markers — navigation aids placed near fold-gate sites. These appear scattered across the world as interactable tiles. No one currently understands what they mark.
  - Dormant fold-gates — appear as strange stone arches, overgrown, in remote locations.
  - Null Refineries — underground facilities, sealed and forgotten, now slowly leaking.
  - Fragments of their written language — found in ruins, decipherable with enough clues.

---

## Chapter Structure

```
Chapter 1 — The Quiet Sickness      [IMPLEMENTED]
Chapter 2 — The Vein Runs Deeper    [PLANNED]
Chapter 3 — The Far Shore           [PLANNED]
Chapter 4 — The Fold                [PLANNED]
Chapter 5 — The Null Refineries     [PLANNED]
Epilogue   — The Long Mending       [PLANNED]
```

---

## Chapter 1 — The Quiet Sickness

**Status:** Implemented. Quests: `herbalist_remedy`, `valley_witness`. All Ch1 NPCs placed.

### Premise
The player arrives in a starting valley. Animals are behaving wrongly — wolves won't retreat, livestock won't eat. A herbalist named Mara has been quietly investigating and suspects the old moonstone mine east of the village is the culprit. A courier named Edda arrives with corroborating reports from other regions.

### Key Locations
| Location | Description |
|---|---|
| Player spawn | Center of the starting valley. Village well, a few scattered buildings. |
| Mara's position | ~10 tiles east-southeast of spawn, on the village edge. |
| Village well | ~6 tiles northeast of spawn. Contaminated. Quest interactable. |
| Birch grove | ~22–24 tiles east. Landmark between village and mine. |
| Moonstone mine | ~40 tiles east. Labyrinth entrance. Contains a Null leak point. Aetherian rune tiles inside. |
| Clean spring | ~20 tiles southwest. Uncontaminated water source. |

### Key NPCs
| NPC | Role |
|---|---|
| Mara | Herbalist and quest giver (`herbalist_remedy`). Practical, observant. Suspects the mine; doesn't know about Null. Post-quest gives crystalline ore hint (sets `mara_crystalline_hint`). |
| Edda | Traveling courier, quest giver (`valley_witness`). Placed near the well (~4 tiles NE of spawn). Has documented the same sickness across a dozen regions. Completion sets `aldric_known` (Ch2 seed). |
| Farmer Ren | Ambient NPC (~8 tiles N of spawn). Worried about livestock. Quest step in `valley_witness`. |
| Storyteller | Narrative recall NPC (~6 tiles NW of spawn). Speaks the highest-priority Ch1 event the player has witnessed. No quest giving. |
| Corrupted Golem (boss) | Guardian construct left by the Aetherians. Now malfunctioning due to Null saturation. |

### Quest Flow
**herbalist_remedy** — Mara's quest (3 branches: herbs / mine / both)
1. Player meets Mara → she describes symptoms and suspects the mine
2. Player investigates mine → discovers cracked ore seam leaking dark residue
3. Player seals the leak and retrieves contaminated ore as evidence
4. Mara analyses the ore → identifies moonstone residue, brews a local remedy
5. Player gathers herbs + clean water → Mara completes the antidote
6. Wildlife in the valley begins to recover

**valley_witness** — Edda's quest (single branch)
1. Player meets Edda near the well → she describes the wider pattern
2. Player examines the contaminated well
3. Player speaks with Farmer Ren about his animals
4. Player returns to Edda → she names Aldric Farrow in Tidehaven (Ch2 seed)

### What the Player Doesn't Know Yet
- The seam they sealed is one of hundreds. The Null is in every moonstone vein across the world.
- The corrupted golem was an Aetherian construct. The rune markings inside the mine are Aetherian script.
- The "dark residue" is Null — the player has no word for it yet.
- Aldric Farrow knows the eastern waters — but the player doesn't know why that matters.

### Seeds for Chapter 2
- Mara (post-quest): "This ore is crystalline — not just contaminated. Structured. Like something refined it." Sets `mara_crystalline_hint`.
- Edda (quest completion): Names Aldric Farrow in **Tidehaven** (the coastal city). Sets `aldric_known`.
- Rune tiles inside the mine (Aetherian script, unreadable). Interaction sets `rune_tile_touched`.
- Storyteller NPC recalls all Ch1 events in order of significance.

---

## Chapter 2 — The Vein Runs Deeper

**Status:** Planned. No implementation.

### Premise
After solving the local crisis, the player learns the sickness isn't contained to this valley. The moonstone veins run continent-wide and the contamination is spreading along them. Following the mineral trail leads to the coast — and the need to sail.

### Core Question
*How is the ore getting contaminated, and where does the contamination originate?*

### Key Beats
1. **Pattern emerges** — A travelling scholar (new NPC) arrives in the valley having mapped sickness reports from multiple regions. The reports cluster around areas with dense moonstone deposits. The scholar has also documented rune markers — they appear near every cluster.
2. **Following the veins** — The player must travel through 2–3 regions, each with a local sickness quest variant (different animal, different terrain, same root cause). Each region contains a rune marker.
3. **Tidehaven** (the coastal city) — A larger settlement on the coast. A cartographer NPC here has old nautical charts showing that the contamination pattern points to a chain of islands far to the east — beyond normal sailing routes. Aldric Farrow, a retired captain named by Edda, knows the waters.
4. **Acquiring a better boat** — The player's current boat is insufficient. A sub-quest to repair or commission a vessel capable of open-ocean travel.
5. **Chapter end** — The player sails east.

### Key NPCs
| NPC | Role |
|---|---|
| The Scholar | Travelling academic who has noticed the pattern. Becomes an information hub. Can translate partial Aetherian script fragments found in chapter 1. |
| The Cartographer | Holds the charts pointing east. Can be convinced to share them. |
| Captain Aldric (or similar) | Knows the eastern islands. Retired, reluctant. Has his own reasons to go back. |

### Key Locations
| Location | Description |
|---|---|
| 2–3 mid-chapter regions | Each a new biome with a local sickness encounter. Rune markers present. |
| Tidehaven (coastal city) | Larger hub. Market, cartographer, docks, tavern with rumours. Home of Aldric Farrow. |
| Open ocean crossing | Transition sequence. Possible encounter at sea (storm, creature, ghost ship). |

### Seeds for Chapter 3
- Captain Aldric mentions a chain of "dead islands" — no wildlife, no settlers, covered in strange stone arches. He's never gone ashore.
- The Scholar deciphers a partial rune inscription: *"...gate of the second order... do not approach without calibration..."*
- A rune marker near the coast glows faintly when the player approaches — more active than the others. Something nearby is still powered.

---

## Chapter 3 — The Far Shore

**Status:** Planned. No implementation.

### Premise
The player reaches the eastern island chain. It is desolate — vegetation sparse, no animals, the ground faintly dark. The ruins of an Aetherian settlement are here, along with a dormant fold-gate. Reactivating the gate requires understanding what the Aetherians built and gathering components from across the ruins.

### Core Question
*Who built this, and where does their gate lead?*

### Key Beats
1. **Landfall** — The islands are visually striking: stone structures half-buried in earth, rune markers everywhere, a faint crystalline sheen on exposed rocks. Null concentration is much higher here — the player's character begins noticing mild symptoms (flavour text: headaches, strange dreams).
2. **Exploring the ruins** — Multiple buildings/dungeons to explore. Each contains Aetherian records (readable once the Scholar translates enough fragments) explaining the civilization's history.
3. **The fold-gate** — A massive stone arch in the center of the main island. Clearly artificial. Needs three components to reactivate:
   - A **Resonance Core** — pulled from a still-active Aetherian machine in the ruins
   - A **Null Capacitor** — a sealed container of refined Null, found in a sealed chamber
   - A **Gate Key** — an Aetherian calibration artifact, held by the ruins' automated guardian
4. **The Guardian** — A larger, more intact version of the corrupted golem from chapter 1. Now recognized by the player as the same type of construct. This one is still following its original programming: protect the gate.
5. **Gate activation** — Powering the gate causes a tremor. The air around the arch distorts. Beyond it: nothing recognizable.

### Key NPCs
| NPC | Role |
|---|---|
| Captain Aldric | Guide and moral anchor. Increasingly unsettled by what they find. |
| The Scholar | Translating records on the fly. Gets more excited the deeper they go — dangerously so. |
| Automated systems | Aetherian constructs in the ruins, some hostile (protecting data), some passive (still running maintenance routines). |

### Key Locations
| Location | Description |
|---|---|
| Island chain | 3–4 islands. Outer islands: ruins and rune markers. Central island: the fold-gate site. |
| Aetherian settlement | Partially intact. Residential structures, a research hall, a sealed refinery annex (locked until chapter 5). |
| The fold-gate | The centrepiece. A 3-tile-wide arch of dark stone covered in rune script. When active, it shows a shimmering aperture. |

### Seeds for Chapter 4
- The Aetherian records mention "the fold" — the space between gate endpoints. Their records warn: *"Do not linger in the fold. Null density is absolute. Keep movement time under twelve heartbeats."*
- The Scholar finds a gate directory — a list of other gate locations. One entry is marked with a symbol that repeats throughout the records: a circle with three inward-pointing lines. It appears to mark their home facility.
- Aldric refuses to go through the gate. He stays behind with the boat.

---

## Chapter 4 — The Fold

**Status:** Planned. No implementation.

### Premise
The players step through the fold-gate and enter the space between gates — a liminal realm of compressed space where Null is fully visible as drifting luminous particles. It is not safe to stay long. The path through leads to another gate: this one active, leading to the Aetherian home continent.

### Core Question
*What is this place, and what does it mean that Null is everywhere here?*

### Key Beats
1. **The Fold itself** — A surreal environment. No sky, no ground in the conventional sense — a vast dark space filled with floating geometry (fragments of Aetherian architecture suspended in the fold by the collapsed network). Null particles drift visibly like snow. The player can explore for a limited time before they need to exit.
2. **Navigation** — The player must find the correct exit gate among several dormant ones. Clues come from the gate directory found in chapter 3.
3. **Revelation** — Floating in the fold is the wreckage of an Aetherian vessel — evidence that the fold was once a transit corridor for ships as well as foot traffic. Among the wreckage: a full Aetherian historical record, intact. This is the moment the player learns everything: who the Aetherians were, what Null is, what happened to them.
4. **Exit** — The active gate leads not to a new region of the known world but to an entirely different continent — the Aetherian homeland, far beyond any map the player has seen.

### Tone
The Fold should feel like the inside of something ancient and sad — a graveyard of a civilization's greatest achievement. The Null particles are beautiful but wrong. The floating ruins are enormous and silent.

### Key Mechanics (Design Notes)
- Limited time in the Fold (Null exposure counter — not punishing, but creates urgency)
- Non-combat navigation puzzle
- Major lore dump via readable records — this is the turning point where the player understands the full picture

---

## Chapter 5 — The Null Refineries

**Status:** Planned. No implementation.

### Premise
The players arrive on the Aetherian home continent. The civilization's capital is here — half-intact, enormous, and still running on automated systems. The Null Refineries are here too, and they are still operational. Still leaking. Have been for centuries. The player must shut them down permanently.

### Core Question
*How do we stop the source, and can it be undone?*

### Key Beats
1. **The capital** — A city of Aetherian architecture, vast and empty. Some automated systems still run: lights, doors, maintenance constructs. The world's most intact source of Aetherian knowledge. Also the most Null-saturated environment yet — human symptoms are now more pronounced (flavour text).
2. **Understanding the refineries** — The player must explore at least two of the three active refineries. Each one has a different failure mode: one has a cracked containment vessel, one has an overloaded processor, one has a corrupted control system. Each requires a different approach to shut down safely.
3. **The choice** — The refineries can be:
   - **Shut down cold** — safe, immediate, but destroys centuries of Aetherian knowledge stored in the same systems
   - **Shut down with a controlled drain** — slower, requires more work, but preserves the knowledge and allows the Aetherian records to be recovered for the world
   - **Vented** — fast, catastrophic, destroys the refineries and accelerates Null dispersal for a generation before it finally clears
4. **The final guardian** — The capital's central AI construct — not malevolent, just following its last instruction: *keep the refineries running*. It can be defeated, reasoned with (with enough Aetherian knowledge gathered), or bypassed.
5. **Shutdown** — The refineries go dark. Null stops entering the moonstone seams. Recovery begins — slowly, over years, not overnight.

### Key NPCs
| NPC | Role |
|---|---|
| The Scholar | Has been building toward this their whole life without knowing it. Their arc completes here — the question is whether they want to preserve knowledge or destroy the threat. |
| The Central AI | Not human but not incomprehensible. Speaks in formal Aetherian (translated by the Scholar). Believes it is still serving its creators. |

### Key Locations
| Location | Description |
|---|---|
| Aetherian capital | Vast, partially intact city. Multiple districts to explore. |
| Null Refinery A–C | Underground facilities. Each visually distinct, each mechanically distinct. |
| The Control Spire | The capital's central tower. Final location. Houses the AI construct. |

---

## Epilogue — The Long Mending

**Status:** Planned. No implementation.

### Premise
The refineries are shut down. The players return through the fold-gate network — now partially reactivated by their actions — to the starting valley. Mara is there.

### Key Beats
- Mara notices the well water has changed — it tastes different, cleaner
- She doesn't know what the players did. They can tell her everything or nothing
- Wildlife in the valley is still sick, but no longer getting worse — the long recovery has begun
- The Scholar's choice in chapter 5 affects what happens to Aetherian knowledge: if preserved, new understanding of the world's geology spreads and helps communities accelerate healing; if destroyed, the mending is slower but complete
- Final image: Mara's remedy, brewed from fennel root and spring water, being distributed to villages across the region. Small. Practical. A beginning.

---

## World-Building Reference

### Null — Properties and Rules
| Property | Detail |
|---|---|
| Source | Falls from space as microscopic crystalline particles, essentially continuously but at low density |
| Natural state | Inert. Disperses harmlessly in open air. Does not accumulate without a concentrating agent. |
| Moonstone interaction | Moonstone ore acts as a natural Null conductor and accumulator. Null concentrates in moonstone seams over time. |
| Aetherian refinement | The Aetherians learned to purify Null into a fuel source for fold-gates. Refined Null is highly stable but catastrophic if containment fails. |
| Contamination mechanism | Leaking refined Null re-enters the moonstone seams, but in concentrated form — far more toxic than natural accumulation would ever produce. |
| In the Fold | Null is fully visible here — drifting luminous particles. Extremely high density. Short-term exposure causes disorientation; long-term exposure is fatal. |
| Cure | Removing the source (sealing leaks, shutting refineries) stops new contamination. Existing Null in the seams disperses over years. Mara's remedy treats symptoms but cannot accelerate dispersal. |

### Aetherian Script and Runes
- Rune markers in the world are Aetherian navigation aids — placed near fold-gate sites to help travelers orient themselves
- The script appears in three forms: black (common signage), grey (technical documentation), blue (restricted/classified)
- No living person can read it at the start of the game. The Scholar learns progressively through chapters 2–4.
- Full fluency by chapter 5 is required to negotiate with the central AI.

### The Fold-Gate Network
- Gates are paired — each gate has a fixed destination
- The fold (the space between) is shared — all gates connect through the same space
- The network collapsed when the Aetherian disaster destroyed most gate endpoints simultaneously
- As the players reactivate gates, the fold becomes more navigable
- Gates require Null power to operate — ironic given that Null is the cause of the problem

### Rune Markers in the Starting World
Rune markers are already placed procedurally across all land regions. Their in-world explanation: they are Aetherian waypoints, placed centuries ago to guide travelers near fold-gate approach corridors. Most are near defunct gate sites. The cluster near Tidehaven is near a gate that is *almost* still active — which is why that marker glows slightly warmer than others. This is discoverable in chapter 2.

---

## Continuity Checklist

When writing a new quest, verify:
- [ ] Does this contradict the established cause of the sickness (Null in moonstone seams via leaking refineries)?
- [ ] Is the player's knowledge state accurate? (They don't know what Null is until mid-chapter 4)
- [ ] Do any new NPCs already know about the Aetherians? (They shouldn't — this knowledge is lost)
- [ ] Do rune markers in the relevant region make narrative sense as Aetherian waypoints?
- [ ] Does the quest's local symptom (sick wildlife, bad water, feral animals) fit the Null contamination model?
- [ ] If this quest introduces a named Aetherian artifact or location, is it added to this document?
