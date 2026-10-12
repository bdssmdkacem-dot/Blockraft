extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const DESIGN_SIZE := Vector2(1280.0, 720.0)

var menu_column: VBoxContainer
var status_label: Label
var settings_open := false

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_interface()
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()

func _draw() -> void:
    var sx := size.x / DESIGN_SIZE.x
    var sy := size.y / DESIGN_SIZE.y
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, sy))

    # Sky, distant haze and a warm sunrise.
    draw_rect(Rect2(0, 0, 1280, 720), Color("#8bd0e8"))
    draw_rect(Rect2(0, 0, 1280, 280), Color("#b8e8f0"))
    draw_circle(Vector2(1000, 120), 58, Color("#fff2b0"))
    draw_circle(Vector2(1000, 120), 74, Color(1.0, 0.92, 0.62, 0.16))

    # Distant, stepped mountain range.
    _poly([Vector2(0, 390), Vector2(120, 260), Vector2(210, 330), Vector2(350, 210), Vector2(485, 350), Vector2(625, 245), Vector2(760, 355), Vector2(905, 225), Vector2(1050, 345), Vector2(1165, 270), Vector2(1280, 355), Vector2(1280, 540), Vector2(0, 540)], Color("#7caeb0"))
    _poly([Vector2(70, 315), Vector2(120, 260), Vector2(155, 300), Vector2(128, 292), Vector2(112, 307)], Color("#e6f3e9"))
    _poly([Vector2(280, 280), Vector2(350, 210), Vector2(410, 274), Vector2(371, 258), Vector2(350, 269), Vector2(328, 250)], Color("#edf5e7"))
    _poly([Vector2(838, 292), Vector2(905, 225), Vector2(969, 292), Vector2(932, 274), Vector2(906, 283), Vector2(886, 263)], Color("#f2f5df"))
    _poly([Vector2(1128, 307), Vector2(1165, 270), Vector2(1205, 310), Vector2(1175, 296), Vector2(1159, 302)], Color("#eaf4e4"))

    # Floating island silhouette and tiny voxel ruins.
    _poly([Vector2(910, 190), Vector2(950, 177), Vector2(980, 184), Vector2(1008, 174), Vector2(1040, 190), Vector2(1022, 208), Vector2(994, 214), Vector2(978, 238), Vector2(960, 215), Vector2(932, 208)], Color("#4f8760"))
    for i in range(4):
        draw_rect(Rect2(942 + i * 15, 180 + (i % 2) * 5, 15, 12), Color("#78a96a"))
    draw_rect(Rect2(975, 150, 13, 28), Color("#a8b9a0"))
    draw_rect(Rect2(988, 158, 13, 20), Color("#d9c18b"))

    # Main rolling hills.
    _poly([Vector2(0, 445), Vector2(160, 390), Vector2(310, 432), Vector2(480, 365), Vector2(650, 418), Vector2(820, 360), Vector2(1010, 420), Vector2(1150, 370), Vector2(1280, 410), Vector2(1280, 720), Vector2(0, 720)], Color("#5fbd69"))
    _poly([Vector2(0, 520), Vector2(190, 470), Vector2(350, 500), Vector2(540, 445), Vector2(710, 500), Vector2(900, 440), Vector2(1100, 490), Vector2(1280, 450), Vector2(1280, 720), Vector2(0, 720)], Color("#3e9c58"))

    # River winding toward the foreground.
    _poly([Vector2(780, 405), Vector2(846, 409), Vector2(817, 468), Vector2(876, 520), Vector2(840, 575), Vector2(925, 640), Vector2(912, 720), Vector2(738, 720), Vector2(767, 651), Vector2(728, 594), Vector2(775, 530), Vector2(746, 470)], Color("#6bd4e4"))
    _poly([Vector2(794, 414), Vector2(817, 419), Vector2(791, 471), Vector2(850, 520), Vector2(815, 575), Vector2(896, 642), Vector2(880, 720), Vector2(849, 720), Vector2(864, 646), Vector2(784, 578), Vector2(821, 521), Vector2(768, 468)], Color("#a5edf1"))

    # Voxel trees: layered block canopy, trunk, and highlight blocks.
    _tree(140, 390, 1.25)
    _tree(250, 430, 0.95)
    _tree(410, 400, 1.1)
    _tree(1100, 410, 1.35)
    _tree(1190, 430, 0.95)
    _tree(1010, 465, 0.75)

    # Starter village and a small stone keep.
    _house(520, 405, 0.85, Color("#d8b77d"), Color("#9b6046"))
    _house(610, 430, 0.68, Color("#ead29a"), Color("#8e5140"))
    _house(1050, 370, 0.95, Color("#c6d0c2"), Color("#647e78"))
    draw_rect(Rect2(1090, 327, 18, 46), Color("#e6d7ad"))
    draw_rect(Rect2(1094, 337, 10, 13), Color("#78c8db"))
    draw_rect(Rect2(1078, 318, 43, 12), Color("#536d62"))
    draw_rect(Rect2(1086, 307, 12, 11), Color("#536d62"))
    draw_rect(Rect2(1103, 307, 12, 11), Color("#536d62"))

    # Foreground blocky grass ledges give the scene depth.
    for i in range(16):
        var x := i * 86 - 18
        var y := 625 + int((i % 3) * 13)
        draw_rect(Rect2(x, y, 88, 25), Color("#34854b"))
        draw_rect(Rect2(x, y, 88, 7), Color("#7ed36b"))
        draw_rect(Rect2(x + 6, y + 25, 75, 12), Color("#79543a"))

    # Subtle vignette at the top keeps the title legible.
    draw_rect(Rect2(0, 0, 1280, 155), Color(0.08, 0.18, 0.20, 0.23))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _poly(points: PackedVector2Array, color: Color) -> void:
    draw_colored_polygon(points, color)

func _tree(x: float, ground_y: float, scale: float) -> void:
    draw_rect(Rect2(x - 5 * scale, ground_y - 48 * scale, 12 * scale, 51 * scale), Color("#805334"))
    draw_rect(Rect2(x - 27 * scale, ground_y - 73 * scale, 25 * scale, 25 * scale), Color("#2f7546"))
    draw_rect(Rect2(x - 2 * scale, ground_y - 91 * scale, 28 * scale, 28 * scale), Color("#3b8f4e"))
    draw_rect(Rect2(x - 17 * scale, ground_y - 105 * scale, 24 * scale, 22 * scale), Color("#59ac58"))
    draw_rect(Rect2(x + 6 * scale, ground_y - 81 * scale, 17 * scale, 16 * scale), Color("#70c665"))
    draw_rect(Rect2(x - 27 * scale, ground_y - 73 * scale, 25 * scale, 5 * scale), Color("#438d4b"))

func _house(x: float, ground_y: float, scale: float, wall: Color, roof: Color) -> void:
    draw_rect(Rect2(x, ground_y - 43 * scale, 54 * scale, 43 * scale), wall)
    _poly([Vector2(x - 7 * scale, ground_y - 43 * scale), Vector2(x + 27 * scale, ground_y - 69 * scale), Vector2(x + 61 * scale, ground_y - 43 * scale)], roof)
    draw_rect(Rect2(x + 22 * scale, ground_y - 26 * scale, 12 * scale, 26 * scale), Color("#5c4936"))
    draw_rect(Rect2(x + 7 * scale, ground_y - 33 * scale, 10 * scale, 10 * scale), Color("#77d2df"))
    draw_rect(Rect2(x + 39 * scale, ground_y - 33 * scale, 9 * scale, 10 * scale), Color("#77d2df"))

func _build_interface() -> void:
    var top_bar := HBoxContainer.new()
    top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top_bar.offset_left = 38
    top_bar.offset_top = 24
    top_bar.offset_right = -38
    top_bar.offset_bottom = 72
    top_bar.add_theme_constant_override("separation", 12)
    add_child(top_bar)

    var brand := Label.new()
    brand.text = "BLOCKRAFT"
    brand.add_theme_font_size_override("font_size", 25)
    brand.add_theme_color_override("font_color", Color("#fff7d7"))
    brand.add_theme_color_override("font_shadow_color", Color("#173d32"))
    brand.add_theme_constant_override("shadow_offset_x", 2)
    brand.add_theme_constant_override("shadow_offset_y", 3)
    top_bar.add_child(brand)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    top_bar.add_child(spacer)
    var edition := Label.new()
    edition.text = "VOXEL ADVENTURE  •  EARLY ACCESS"
    edition.add_theme_font_size_override("font_size", 12)
    edition.add_theme_color_override("font_color", Color("#e5f7ec"))
    top_bar.add_child(edition)

    var title := Label.new()
    title.text = "BLOCKRAFT"
    title.position = Vector2(66, 110)
    title.size = Vector2(550, 96)
    title.add_theme_font_size_override("font_size", 68)
    title.add_theme_color_override("font_color", Color("#fff3c2"))
    title.add_theme_color_override("font_shadow_color", Color("#244d38"))
    title.add_theme_constant_override("shadow_offset_x", 4)
    title.add_theme_constant_override("shadow_offset_y", 6)
    title.add_theme_constant_override("outline_size", 5)
    title.add_theme_color_override("font_outline_color", Color("#315b42"))
    add_child(title)

    var tagline := Label.new()
    tagline.text = "BUILD YOUR WORLD. FIND YOUR WILD."
    tagline.position = Vector2(73, 199)
    tagline.size = Vector2(490, 32)
    tagline.add_theme_font_size_override("font_size", 17)
    tagline.add_theme_color_override("font_color", Color("#f4ffec"))
    tagline.add_theme_color_override("font_shadow_color", Color("#214a35"))
    tagline.add_theme_constant_override("shadow_offset_x", 2)
    tagline.add_theme_constant_override("shadow_offset_y", 2)
    add_child(tagline)

    var panel := PanelContainer.new()
    panel.position = Vector2(70, 268)
    panel.size = Vector2(355, 322)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.07, 0.18, 0.15, 0.88)
    panel_style.border_color = Color("#b7d995")
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(12)
    panel_style.content_margin_left = 20
    panel_style.content_margin_right = 20
    panel_style.content_margin_top = 18
    panel_style.content_margin_bottom = 18
    panel.add_theme_stylebox_override("panel", panel_style)
    add_child(panel)

    menu_column = VBoxContainer.new()
    menu_column.add_theme_constant_override("separation", 10)
    panel.add_child(menu_column)
    _add_menu_button("▶   PLAY WORLD", "play", true)
    _add_menu_button("▦   WORLDS", "worlds", false)
    _add_menu_button("⚒   HOW TO PLAY", "help", false)
    _add_menu_button("⚙   SETTINGS", "settings", false)

    status_label = Label.new()
    status_label.text = "A new world is waiting."
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 13)
    status_label.add_theme_color_override("font_color", Color("#d7f0c6"))
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.custom_minimum_size = Vector2(0, 36)
    menu_column.add_child(status_label)

    var footer := Label.new()
    footer.text = "EXPLORE  •  MINE  •  BUILD  •  SURVIVE"
    footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    footer.offset_left = 0
    footer.offset_top = -42
    footer.offset_right = 0
    footer.offset_bottom = -16
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_font_size_override("font_size", 15)
    footer.add_theme_color_override("font_color", Color("#f1ffe8"))
    footer.add_theme_color_override("font_shadow_color", Color("#17452f"))
    footer.add_theme_constant_override("shadow_offset_x", 2)
    footer.add_theme_constant_override("shadow_offset_y", 2)
    add_child(footer)

func _add_menu_button(caption: String, action: String, primary: bool) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(0, 48 if primary else 43)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_size_override("font_size", 18 if primary else 16)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#d8a94d") if primary else Color("#294e3e")
    normal.border_color = Color("#fff0b2") if primary else Color("#8ab878")
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(7)
    normal.content_margin_left = 14
    normal.content_margin_right = 14
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color("#f1c86c") if primary else Color("#3d6c4b")
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("#b98431") if primary else Color("#1d3c31")
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("focus", hover)
    button.add_theme_color_override("font_color", Color("#173729") if primary else Color("#f0f8e6"))
    button.add_theme_color_override("font_hover_color", Color("#132d23"))
    button.add_theme_color_override("font_pressed_color", Color("#132d23"))
    button.pressed.connect(_on_menu_action.bind(action))
    menu_column.add_child(button)

func _on_menu_action(action: String) -> void:
    match action:
        "play":
            get_tree().change_scene_to_file(GAME_SCENE)
        "worlds":
            status_label.text = "WORLD SELECT  •  The Meadowlands is ready. More biomes are coming."
        "help":
            status_label.text = "WASD: move   •   SPACE: jump   •   MOUSE: look   •   LEFT CLICK: mine   •   RIGHT CLICK: build"
        "settings":
            settings_open = not settings_open
            status_label.text = "SETTINGS  •  Audio and graphics options will be added after the first playable build." if settings_open else "A new world is waiting."
