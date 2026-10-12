extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const DESIGN_SIZE := Vector2(1280.0, 720.0)

var menu_column: VBoxContainer
var status_label: Label
var settings_open := false
var dialog_layer: Control

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _build_3d_backdrop()
    _build_interface()
    _build_feature_strip()
    _apply_responsive_layout()
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()
        if is_node_ready():
            _apply_responsive_layout()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel") and is_instance_valid(dialog_layer):
        dialog_layer.queue_free()
        get_viewport().set_input_as_handled()

func _draw() -> void:
    # The former flat polygon panorama has been retired. The menu now renders
    # a real 3D voxel world in a SubViewport behind the interface.
    pass

func _poly(points: Array, color: Color) -> void:
    draw_colored_polygon(PackedVector2Array(points), color)

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


func _apply_responsive_layout() -> void:
    # Keep the reference composition intact while scaling it uniformly for
    # smaller Android landscape viewports. Center letterboxed UI rather than
    # stretching controls or letting the feature strip run off-screen.
    var viewport_size := size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return
    var ui_scale := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
    var ui_origin := Vector2(
        (viewport_size.x - DESIGN_SIZE.x * ui_scale) * 0.5,
        (viewport_size.y - DESIGN_SIZE.y * ui_scale) * 0.5
    )

    _place_scaled_control("TopBar", Vector2(42, 20), Vector2(1196, 42), ui_origin, ui_scale)
    _place_scaled_control("GameTitle", Vector2(42, 58), Vector2(570, 86), ui_origin, ui_scale)
    _place_scaled_control("Tagline", Vector2(58, 139), Vector2(500, 30), ui_origin, ui_scale)
    _place_scaled_control("MainMenuPanel", Vector2(44, 184), Vector2(258, 252), ui_origin, ui_scale)
    _place_scaled_control("FeatureStrip", Vector2(18, 466), Vector2(1244, 180), ui_origin, ui_scale)
    _place_scaled_control("Footer", Vector2(0, 672), Vector2(1280, 32), ui_origin, ui_scale)


func _place_scaled_control(node_name: String, design_position: Vector2, design_size: Vector2, origin: Vector2, ui_scale: float) -> void:
    var control := get_node_or_null(node_name) as Control
    if control == null:
        return
    control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    control.position = origin + design_position * ui_scale
    control.size = design_size
    control.scale = Vector2.ONE * ui_scale

func _build_3d_backdrop() -> void:
    var backdrop := SubViewportContainer.new()
    backdrop.name = "ThreeDMenuBackdrop"
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.stretch = true
    backdrop.size = size
    # Keep the viewport texture in the normal canvas layer. A strongly negative
    # z-index can place it behind the root canvas clear in the CI capture path.
    backdrop.z_index = 0
    backdrop.z_as_relative = false
    add_child(backdrop)
    move_child(backdrop, 0)

    var viewport := SubViewport.new()
    viewport.name = "WorldViewport"
    viewport.size = Vector2i(1280, 720)
    viewport.disable_3d = false
    viewport.transparent_bg = false
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.handle_input_locally = false
    backdrop.add_child(viewport)

    var world := Node3D.new()
    world.name = "VoxelMenuWorld"
    world.set_script(load("res://scripts/menu_world_3d.gd"))
    viewport.add_child(world)


func _build_interface() -> void:
    var top_bar := HBoxContainer.new()
    top_bar.name = "TopBar"
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
    title.name = "GameTitle"
    title.text = "BLOCKRAFT"
    title.position = Vector2(42, 58)
    title.size = Vector2(570, 86)
    title.add_theme_font_size_override("font_size", 72)
    title.add_theme_color_override("font_color", Color("#fff3c2"))
    title.add_theme_color_override("font_shadow_color", Color("#244d38"))
    title.add_theme_constant_override("shadow_offset_x", 4)
    title.add_theme_constant_override("shadow_offset_y", 6)
    title.add_theme_constant_override("outline_size", 5)
    title.add_theme_color_override("font_outline_color", Color("#315b42"))
    add_child(title)

    var tagline := Label.new()
    tagline.name = "Tagline"
    tagline.text = "BUILD YOUR WORLD. FIND YOUR WILD."
    tagline.position = Vector2(58, 139)
    tagline.size = Vector2(500, 30)
    tagline.add_theme_font_size_override("font_size", 17)
    tagline.add_theme_color_override("font_color", Color("#f4ffec"))
    tagline.add_theme_color_override("font_shadow_color", Color("#214a35"))
    tagline.add_theme_constant_override("shadow_offset_x", 2)
    tagline.add_theme_constant_override("shadow_offset_y", 2)
    add_child(tagline)

    var panel := PanelContainer.new()
    panel.name = "MainMenuPanel"
    panel.position = Vector2(44, 184)
    panel.size = Vector2(258, 252)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.025, 0.045, 0.055, 0.88)
    panel_style.border_color = Color("#7fe4a0")
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(5)
    panel_style.content_margin_left = 12
    panel_style.content_margin_right = 12
    panel_style.content_margin_top = 12
    panel_style.content_margin_bottom = 12
    panel.add_theme_stylebox_override("panel", panel_style)
    add_child(panel)

    menu_column = VBoxContainer.new()
    menu_column.add_theme_constant_override("separation", 6)
    panel.add_child(menu_column)
    _add_menu_button("▶   PLAY WORLD", "play", true)
    _add_menu_button("▦   WORLDS", "worlds", false)
    _add_menu_button("⚒   HOW TO PLAY", "help", false)
    _add_menu_button("⚙   SETTINGS", "settings", false)

    status_label = Label.new()
    status_label.text = "YOUR WORLD. YOUR ADVENTURE."
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_font_size_override("font_size", 11)
    status_label.add_theme_color_override("font_color", Color("#d7f0c6"))
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.custom_minimum_size = Vector2(0, 22)
    menu_column.add_child(status_label)

    var footer_band := ColorRect.new()
    footer_band.name = "FooterBand"
    footer_band.anchor_left = 0.0
    footer_band.anchor_top = 1.0
    footer_band.anchor_right = 1.0
    footer_band.anchor_bottom = 1.0
    footer_band.offset_top = -70
    footer_band.offset_bottom = 0
    footer_band.color = Color("#07141c")
    footer_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(footer_band)

    var footer := Label.new()
    footer.name = "Footer"
    footer.text = "◇  PROCEDURAL WORLDS     •     🌲  DYNAMIC BIOMES     •     ⛏  MINE / CRAFT / BUILD     •     ☀  DAY & NIGHT"
    footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    footer.offset_left = 0
    footer.offset_top = -48
    footer.offset_right = 0
    footer.offset_bottom = -12
    footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    footer.add_theme_font_size_override("font_size", 12)
    footer.add_theme_color_override("font_color", Color("#e8f3ff"))
    footer.add_theme_color_override("font_shadow_color", Color("#17452f"))
    footer.add_theme_constant_override("shadow_offset_x", 2)
    footer.add_theme_constant_override("shadow_offset_y", 2)
    add_child(footer)


func _build_feature_strip() -> void:
    var strip := HBoxContainer.new()
    strip.name = "FeatureStrip"
    strip.anchor_left = 0.0
    strip.anchor_top = 0.0
    strip.anchor_right = 0.0
    strip.anchor_bottom = 0.0
    strip.position = Vector2(18, 466)
    strip.size = Vector2(1244, 180)
    strip.add_theme_constant_override("separation", 8)
    add_child(strip)
    var features := [
        {"title":"EXPLORE WORLDS","body":"Mountains, rivers & secrets","action":"worlds","art":"res://assets/ui/cards/explore.svg"},
        {"title":"GATHER RESOURCES","body":"Mine stone, ores & crystals","action":"help","art":"res://assets/ui/cards/mining.svg"},
        {"title":"CRAFT & BUILD","body":"Build block by block","action":"help","art":"res://assets/ui/cards/build.svg"},
        {"title":"SURVIVE THE NIGHT","body":"Prepare before dark","action":"help","art":"res://assets/ui/cards/survive.svg"},
        {"title":"BUILD YOUR DREAMS","body":"Create your own home","action":"play","art":"res://assets/ui/cards/dreams.svg"},
        {"title":"MULTIPLAYER","body":"Friend worlds planned","action":"settings","art":"res://assets/ui/cards/multiplayer.svg"}
    ]
    for feature in features:
        var card := Control.new()
        card.custom_minimum_size = Vector2(0, 174)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.size_flags_vertical = Control.SIZE_EXPAND_FILL
        card.clip_contents = true
        strip.add_child(card)
        var art := TextureRect.new()
        art.name = "CardArtwork"
        art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        art.stretch_mode = TextureRect.STRETCH_SCALE
        art.texture = load(feature.art) as Texture2D
        art.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(art)
        var shade := ColorRect.new()
        shade.anchor_top = 0.70
        shade.anchor_right = 1.0
        shade.anchor_bottom = 1.0
        shade.color = Color(0.025, 0.055, 0.06, 0.84)
        shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(shade)
        var content := VBoxContainer.new()
        content.anchor_top = 0.72
        content.anchor_right = 1.0
        content.anchor_bottom = 1.0
        content.offset_left = 4
        content.offset_right = -4
        content.offset_top = 2
        content.offset_bottom = -2
        content.add_theme_constant_override("separation", 2)
        content.mouse_filter = Control.MOUSE_FILTER_IGNORE
        card.add_child(content)
        var heading := Label.new()
        heading.text = feature.title
        heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        heading.add_theme_font_size_override("font_size", 12)
        heading.add_theme_color_override("font_color", Color("#fff5d9"))
        content.add_child(heading)
        var detail := Label.new()
        detail.text = feature.body
        detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        detail.add_theme_font_size_override("font_size", 10)
        detail.add_theme_color_override("font_color", Color("#e0e9db"))
        content.add_child(detail)
        var hit_area := Button.new()
        hit_area.name = "CardHitArea"
        hit_area.text = ""
        hit_area.flat = true
        hit_area.focus_mode = Control.FOCUS_ALL
        hit_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        hit_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        hit_area.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
        var hover := StyleBoxFlat.new()
        hover.bg_color = Color(1, 1, 1, 0.08)
        hit_area.add_theme_stylebox_override("hover", hover)
        hit_area.pressed.connect(_on_menu_action.bind(feature.action))
        card.add_child(hit_area)

func _add_menu_button(caption: String, action: String, primary: bool) -> void:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(0, 42 if primary else 39)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_size_override("font_size", 15 if primary else 14)
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
            _start_game()
        "worlds":
            _show_dialog(
                "CHOOSE YOUR WORLD",
                "One world is playable in this prototype. Locked regions are shown honestly and will be added after their terrain and gameplay are ready.",
                [
                    {"label": "▶  PLAY THE MEADOWLANDS", "action": "play", "primary": true},
                    {"label": "MOUNTAIN FRONTIER  ·  LOCKED", "action": "locked_mountains"},
                    {"label": "SUNSCORCHED DESERT  ·  LOCKED", "action": "locked_desert"},
                    {"label": "DEEP BLUE OCEAN  ·  LOCKED", "action": "locked_ocean"},
                    {"label": "BACK", "action": "close"}
                ]
            )
        "help":
            _show_dialog(
                "HOW TO PLAY",
                "DESKTOP CONTROLS\nW A S D  ·  Move\nSPACE  ·  Jump\nMOUSE  ·  Look around\nLEFT CLICK  ·  Mine the block under the crosshair\nRIGHT CLICK  ·  Place a block\n\nMobile touch controls are not implemented yet.",
                [{"label": "GOT IT", "action": "close", "primary": true}]
            )
        "settings":
            _show_dialog(
                "SETTINGS",
                "This prototype currently uses the project's default graphics settings. Audio, sensitivity, and graphics controls are not wired yet, so this menu does not pretend those options already work.",
                [{"label": "BACK", "action": "close", "primary": true}]
            )

func _start_game() -> void:
    get_tree().change_scene_to_file(GAME_SCENE)

func _show_dialog(dialog_title: String, description: String, options: Array) -> void:
    if is_instance_valid(dialog_layer):
        dialog_layer.queue_free()

    dialog_layer = Control.new()
    dialog_layer.name = "MenuDialog"
    dialog_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dialog_layer.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dialog_layer)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.025, 0.07, 0.055, 0.76)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP
    dialog_layer.add_child(shade)

    var panel := PanelContainer.new()
    panel.anchor_left = 0.06
    panel.anchor_top = 0.12
    panel.anchor_right = 0.94
    panel.anchor_bottom = 0.88
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color("#102d25")
    panel_style.border_color = Color("#c3dca0")
    panel_style.set_border_width_all(2)
    panel_style.set_corner_radius_all(14)
    panel_style.content_margin_left = 20
    panel_style.content_margin_right = 20
    panel_style.content_margin_top = 20
    panel_style.content_margin_bottom = 20
    panel.add_theme_stylebox_override("panel", panel_style)
    dialog_layer.add_child(panel)

    var content_box := VBoxContainer.new()
    content_box.add_theme_constant_override("separation", 12)
    panel.add_child(content_box)

    var heading := Label.new()
    heading.text = dialog_title
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    heading.add_theme_font_size_override("font_size", 25)
    heading.add_theme_color_override("font_color", Color("#ffe8a2"))
    content_box.add_child(heading)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_box.add_child(scroll)

    var scroll_content := VBoxContainer.new()
    scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll_content.add_theme_constant_override("separation", 12)
    scroll.add_child(scroll_content)

    var body := Label.new()
    body.text = description
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_theme_font_size_override("font_size", 15)
    body.add_theme_color_override("font_color", Color("#e6f2df"))
    scroll_content.add_child(body)

    var button_stack := VBoxContainer.new()
    button_stack.add_theme_constant_override("separation", 8)
    scroll_content.add_child(button_stack)

    for option in options:
        var option_button := Button.new()
        option_button.text = str(option.get("label", "BACK"))
        option_button.custom_minimum_size = Vector2(0, 42)
        option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        option_button.add_theme_font_size_override("font_size", 15)
        var option_style := StyleBoxFlat.new()
        var is_primary := bool(option.get("primary", false))
        option_style.bg_color = Color("#d8a94d") if is_primary else Color("#294e3e")
        option_style.border_color = Color("#fff0b2") if is_primary else Color("#8ab878")
        option_style.set_border_width_all(1)
        option_style.set_corner_radius_all(6)
        option_button.add_theme_stylebox_override("normal", option_style)
        var hover_style := option_style.duplicate() as StyleBoxFlat
        hover_style.bg_color = Color("#f1c86c") if is_primary else Color("#3d6c4b")
        option_button.add_theme_stylebox_override("hover", hover_style)
        option_button.add_theme_color_override("font_color", Color("#173729") if is_primary else Color("#f0f8e6"))
        option_button.pressed.connect(_on_dialog_action.bind(str(option.get("action", "close"))))
        button_stack.add_child(option_button)

func _on_dialog_action(action: String) -> void:
    match action:
        "play":
            _start_game()
        "close":
            if is_instance_valid(dialog_layer):
                dialog_layer.queue_free()
        "locked_mountains":
            _show_dialog("MOUNTAIN FRONTIER", "LOCKED REGION\nThis biome needs its own reviewed terrain, landmarks, resources, and mobile performance checks before it can be selected.", [{"label": "BACK TO WORLDS", "action": "worlds", "primary": true}, {"label": "CLOSE", "action": "close"}])
        "locked_desert":
            _show_dialog("SUNSCORCHED DESERT", "LOCKED REGION\nThe desert will be selectable only after its original block palette, dunes, oasis landmarks, and resource loop are implemented.", [{"label": "BACK TO WORLDS", "action": "worlds", "primary": true}, {"label": "CLOSE", "action": "close"}])
        "locked_ocean":
            _show_dialog("DEEP BLUE OCEAN", "LOCKED REGION\nThe ocean needs water rendering, underwater readability, and a distinct exploration loop before it is considered playable.", [{"label": "BACK TO WORLDS", "action": "worlds", "primary": true}, {"label": "CLOSE", "action": "close"}])
