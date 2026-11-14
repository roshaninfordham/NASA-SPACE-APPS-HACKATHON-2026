class_name VeilArtProfile
extends Resource
## Swappable presentation slots. No energy, shielding or mission values live here.
@export_group("Scene replacements — local origin at documented anchor")
@export var landscape_scene: PackedScene
@export var habitat_scene: PackedScene
@export var interior_scene: PackedScene
@export var habitat_origin := Vector3(0, 2.4, -16)
@export var refuge_scene: PackedScene
@export var solar_array_scene: PackedScene
@export var companion_scene: PackedScene
@export var scanner_scene: PackedScene
@export_group("Shared palette")
@export var terrain_color := Color("a6523e")
@export var distant_terrain_color := Color("713d37")
@export var hull_color := Color("ddd7bd")
@export var structure_color := Color("283f48")
@export var instrument_color := Color("8bd3c1")
@export var route_color := Color("e6a263")
@export_group("Rendering budget")
@export_range(30, 120, 1) var maximum_fps := 60
@export var shadows_enabled := true
@export_range(0, 200, 10) var dust_particle_count := 90

@export_group("Interface appearance")
@export var interface_font: Font
@export var title_font: Font
@export var interface_text := Color("eee4ce")
@export var interface_accent := Color("d9bc83")
@export var interface_button_text := Color("24323a")
