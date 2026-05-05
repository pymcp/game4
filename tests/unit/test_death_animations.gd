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
