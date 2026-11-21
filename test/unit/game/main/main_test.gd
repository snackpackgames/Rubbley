extends SimulationTestSuite
## Main owns the UI layer (ADR 0016): the HUD outlives levels, and Main points it at each
## level's Rubbley as the level loads.

const MAIN_SCENE := preload("res://game/main/main.tscn")
const SANDBOX_SCENE := preload("res://game/levels/sandbox_level.tscn")


## The HUD watches the start level's Rubbley, and the next level's once it replaces it.
func test_the_hud_watches_each_levels_rubbley() -> void:
	var main: Main = auto_free(MAIN_SCENE.instantiate())
	add_child(main)
	var hud := main.hud
	await get_tree().process_frame
	var watching_start := hud.is_watching()
	main.load_level(SANDBOX_SCENE)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_bool(watching_start).is_true()
	assert_bool(hud.is_watching()).is_true()
	assert_bool(hud.panel.visible).is_true()
