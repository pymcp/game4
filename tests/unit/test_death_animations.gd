extends GutTest


# ── DeathRing ────────────────────────────────────────────────────────

func test_death_ring_can_instantiate() -> void:
    var ring := DeathRing.new()
    add_child_autofree(ring)
    assert_not_null(ring)


func test_death_ring_default_properties() -> void:
    var ring := DeathRing.new()
    add_child_autofree(ring)
    assert_almost_eq(ring.max_radius, 20.0, 0.01)
    assert_almost_eq(ring.lifetime, 0.35, 0.01)
    assert_eq(ring.color, Color.WHITE)
    assert_almost_eq(ring.delay, 0.0, 0.01)


func test_death_ring_properties_settable() -> void:
    var ring := DeathRing.new()
    ring.max_radius = 30.0
    ring.lifetime = 0.5
    ring.color = Color(1.0, 0.4, 0.0)
    ring.delay = 0.06
    add_child_autofree(ring)
    assert_almost_eq(ring.max_radius, 30.0, 0.01)
    assert_almost_eq(ring.lifetime, 0.5, 0.01)
    assert_eq(ring.color, Color(1.0, 0.4, 0.0))
    assert_almost_eq(ring.delay, 0.06, 0.01)


# ── DeathVFX ─────────────────────────────────────────────────────────

func test_element_color_physical() -> void:
    assert_eq(DeathVFX.ELEMENT_COLORS[ItemDefinition.Element.NONE],
        Color("#dddddd"))


func test_element_color_fire() -> void:
    assert_eq(DeathVFX.ELEMENT_COLORS[ItemDefinition.Element.FIRE],
        Color("#ff6600"))


func test_element_color_ice() -> void:
    assert_eq(DeathVFX.ELEMENT_COLORS[ItemDefinition.Element.ICE],
        Color("#44ccff"))


func test_element_color_lightning() -> void:
    assert_eq(DeathVFX.ELEMENT_COLORS[ItemDefinition.Element.LIGHTNING],
        Color("#ffee44"))


func test_element_color_poison() -> void:
    assert_eq(DeathVFX.ELEMENT_COLORS[ItemDefinition.Element.POISON],
        Color("#88ff44"))


func test_tier0_duration() -> void:
    assert_almost_eq(float(DeathVFX.TIER_PARAMS[0][0]), 0.28, 0.001)


func test_tier4_duration() -> void:
    assert_almost_eq(float(DeathVFX.TIER_PARAMS[4][0]), 0.42, 0.001)


func test_tier0_radius() -> void:
    assert_almost_eq(float(DeathVFX.TIER_PARAMS[0][1]), 18.0, 0.01)


func test_tier4_radius() -> void:
    assert_almost_eq(float(DeathVFX.TIER_PARAMS[4][1]), 35.0, 0.01)


func test_play_does_not_crash_with_node2d() -> void:
    var entity := Node2D.new()
    var visual := Node2D.new()
    entity.add_child(visual)
    add_child(entity)
    # Tier 0, physical — no shake, one ring.
    DeathVFX.play(entity, visual, 0, ItemDefinition.Element.NONE)
    # entity will be queue_freed by DeathVFX; autofree on test teardown is fine.
    assert_true(true, "play() did not crash")


# ── Monster element tracking ─────────────────────────────────────────

func test_monster_tracks_last_hit_element() -> void:
    var m := Monster.new()
    add_child_autofree(m)
    m.take_hit(1, null, ItemDefinition.Element.FIRE)
    assert_eq(m._last_hit_element, ItemDefinition.Element.FIRE)


func test_monster_element_updates_on_repeated_hits() -> void:
    var m := Monster.new()
    add_child_autofree(m)
    m.take_hit(1, null, ItemDefinition.Element.FIRE)
    m.take_hit(1, null, ItemDefinition.Element.ICE)
    assert_eq(m._last_hit_element, ItemDefinition.Element.ICE)


func test_monster_element_defaults_to_physical() -> void:
    var m := Monster.new()
    add_child_autofree(m)
    assert_eq(m._last_hit_element, ItemDefinition.Element.NONE)
