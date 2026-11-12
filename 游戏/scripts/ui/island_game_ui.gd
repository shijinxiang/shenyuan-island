extends CanvasLayer
var game:Node
var fishing:Node
var theme_pack:Theme
var clock_button:Button
var context_button:Button
var fishing_button:Button
var spear_button:Button
var context_row:HBoxContainer
var water_hint: Label
var toast:PanelContainer
var toast_text:Label
var toast_time:=0.0
var settings:PanelContainer
var weather_choices:OptionButton
var creative_box:CheckBox
var dialog:PanelContainer
var speaker:Label
var speech:RichTextLabel
var choices:VBoxContainer
var bag:PanelContainer
var bag_grid:GridContainer
var bag_summary:Label
var bag_detail:RichTextLabel
var bag_action:Button
var page_label:Label
var bag_page:=0
var bag_entries:Array=[]
var fish_panel:PanelContainer
var fish_text:Label
var progress_bar:ProgressBar
var tension_bar:ProgressBar
var flash:ColorRect
var cinematic_panel:Control
var cinematic_caption:Label
var cinematic_title:Label
var fade:ColorRect
var intro_buttons:HBoxContainer
var top_controls:HBoxContainer
var letter_button:Button
var seed_button:Button
var tool_button: Button
var choices_scroll: ScrollContainer
var character_page := "bag"
var inventory_content: VBoxContainer
var character_content: HBoxContainer
var character_stats: RichTextLabel
var storage_view: PanelContainer
var settings_content:VBoxContainer
var settings_tween:Tween
var settings_closing:=false
var dialog_close:Button
var reading_letter := false
var letter_tween: Tween

static func box(color:Color,radius:=12) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	style.content_margin_left=16
	style.content_margin_right=16
	style.content_margin_top=10
	style.content_margin_bottom=10
	return style

func _ready() -> void:
	layer=30
	game=get_parent()
	fishing=game.fishing
	theme_pack=Theme.new()
	var font:=preload("res://assets/fonts/NotoSansSC-Regular.otf")
	theme_pack.default_font=font
	theme_pack.default_font_size=17
	var paper:=box(Color("f3e8d1"),16)
	paper.content_margin_left=32;paper.content_margin_right=32
	paper.content_margin_top=22;paper.content_margin_bottom=22
	paper.border_color=Color("b9a88a")
	paper.set_border_width_all(2)
	paper.shadow_color=Color(0.03,.12,.10,.25)
	paper.shadow_size=10
	theme_pack.set_stylebox("panel","PanelContainer",paper)
	for state in ["normal","hover","pressed","disabled"]:
		var color:=Color("31665e")
		if state=="hover":color=Color("438476")
		elif state=="pressed":color=Color("214d48")
		elif state=="disabled":color=Color("b5b9a7")
		var frame:=box(color,12)
		frame.content_margin_left=27;frame.content_margin_right=27;frame.content_margin_bottom=13
		frame.border_color=Color("a8c4aa");frame.set_border_width_all(1)
		frame.shadow_color=Color(.05,.13,.11,.22);frame.shadow_size=3
		theme_pack.set_stylebox(state,"Button",frame)
		theme_pack.set_stylebox(state,"OptionButton",frame.duplicate())
	theme_pack.set_color("font_color","Button",Color("fff5df"))
	theme_pack.set_color("font_hover_color","Button",Color.WHITE)
	theme_pack.set_color("font_disabled_color","Button",Color("666f5d"))
	theme_pack.set_color("font_color","Label",Color("30493f"))
	theme_pack.set_color("font_color","CheckBox",Color("fff5df"))
	theme_pack.set_color("font_hover_color","CheckBox",Color.WHITE)
	theme_pack.set_color("font_color","OptionButton",Color("fff5df"))
	theme_pack.set_color("default_color","RichTextLabel",Color("30493f"))
	theme_pack.set_stylebox("background","ProgressBar",box(Color("d6c8ad"),6))
	theme_pack.set_stylebox("fill","ProgressBar",box(Color("4b927d"),6))
	_build_hud()
	_build_settings()
	_build_dialog()
	_build_bag()
	_build_cinematic()

func button(text:String,callback:Callable) -> Button:
	var result:=preload("res://scripts/ui/nautical_button.gd").new()
	result.theme=theme_pack
	result.text=text
	result.pressed.connect(callback)
	return result

func centered_panel(size:Vector2) -> PanelContainer:
	var result:=preload("res://scripts/ui/nautical_panel.gd").new()
	result.theme=theme_pack
	result.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result.position=-size*.5
	result.custom_minimum_size=size
	add_child(result)
	result.hide()
	return result

func _build_hud() -> void:
	clock_button=button("",toggle_settings)
	clock_button.position=Vector2(20,18)
	add_child(clock_button)
	var top:=HBoxContainer.new()
	top_controls=top
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top.position=Vector2(-245,18)
	add_child(top)
	top.add_child(button("人物  P",toggle_character))
	top.add_child(button("设置  Esc",toggle_settings))
	context_row=HBoxContainer.new()
	context_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	context_row.position=Vector2(-210,-72)
	context_row.alignment=BoxContainer.ALIGNMENT_CENTER
	context_row.custom_minimum_size.x=420
	add_child(context_row)
	context_button=button("",func():game.interact())
	fishing_button=button("F  钓鱼",func():fishing.toggle())
	spear_button=button("Q  鱼叉",func():game.toggle_harpoon())
	seed_button=button("G  播种",func():game.plant_seed())
	tool_button = button("X  工具", func(): game.farming.cycle_tool())
	for control in [context_button,fishing_button,spear_button,seed_button,tool_button]:context_row.add_child(control)
	water_hint = Label.new()
	water_hint.theme = theme_pack
	water_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	water_hint.position = Vector2(-240, -124)
	water_hint.custom_minimum_size.x = 480
	water_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	water_hint.text = "Ctrl 下沉 · 空格 上浮 · 松键悬浮"
	water_hint.add_theme_color_override("font_color", Color.WHITE)
	water_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, .8))
	water_hint.add_theme_constant_override("shadow_offset_x", 1)
	water_hint.add_theme_constant_override("shadow_offset_y", 2)
	water_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water_hint.hide()
	add_child(water_hint)
	toast=PanelContainer.new()
	toast.theme=theme_pack
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.position=Vector2(-270,75)
	toast.custom_minimum_size.x=540
	add_child(toast)
	toast_text=Label.new()
	toast_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	toast.add_child(toast_text)
	toast.hide()
	fish_panel=centered_panel(Vector2(480,95))
	fish_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fish_panel.offset_left = -240
	fish_panel.offset_right = 240
	fish_panel.offset_top = -270
	fish_panel.offset_bottom = -175
	var column:=VBoxContainer.new()
	fish_panel.add_child(column)
	fish_text=Label.new()
	fish_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	fish_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(fish_text)
	var row:=HBoxContainer.new()
	column.add_child(row)
	for title in ["收线","张力"]:
		var label:=Label.new();label.text=title;row.add_child(label)
		var bar:=ProgressBar.new();bar.custom_minimum_size=Vector2(165,18);bar.show_percentage=false;row.add_child(bar)
		if title=="收线":progress_bar=bar
		else:tension_bar=bar
	flash=ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color=Color(.65,.12,.08,0)
	flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(flash)

func _build_settings() -> void:
	settings=centered_panel(Vector2(860,650))
	settings.draw_ornaments=false
	var scroll:=StyleBoxTexture.new()
	scroll.texture=preload("res://assets/ui/nautical_scroll.png")
	scroll.texture_margin_left=140;scroll.texture_margin_right=140;scroll.texture_margin_top=140;scroll.texture_margin_bottom=140
	scroll.content_margin_left=145;scroll.content_margin_right=145;scroll.content_margin_top=110;scroll.content_margin_bottom=90
	settings.add_theme_stylebox_override("panel",scroll)
	var column:=VBoxContainer.new()
	settings_content=column
	column.add_theme_constant_override("separation",10)
	settings.add_child(column)
	var title:=Label.new();title.text="潮汐与旅程";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",25);column.add_child(title)
	var caption:=Label.new();caption.text="时间流速";column.add_child(caption)
	var time_options:=OptionButton.new()
	for multiplier in [1,2,5,10]:time_options.add_item(str(multiplier)+" ×",multiplier)
	time_options.select([1,2,5,10].find(int(game.progress.get("time_scale",1))))
	time_options.item_selected.connect(func(index:int):game.set_time_scale(time_options.get_item_id(index)))
	column.add_child(time_options)
	creative_box=CheckBox.new();creative_box.text="创造模式";creative_box.button_pressed=game.creative()
	creative_box.toggled.connect(func(value:bool):game.progress.creative=value;game.save();weather_choices.visible=value)
	column.add_child(creative_box)
	weather_choices=OptionButton.new()
	for text in ["晴天","阴天","下雨","雷暴"]:weather_choices.add_item(text)
	weather_choices.item_selected.connect(func(index:int):if game.creative():game.weather.set_weather(index))
	column.add_child(weather_choices)
	weather_choices.visible=game.creative()
	letter_button=button("重读岛上的信",func():settings.hide();game.read_letter())
	column.add_child(letter_button)
	column.add_child(button("重看序章",func():settings.hide();game.start_opening()))
	column.add_child(button("收起藏宝图",close_settings))
	settings.visibility_changed.connect(_settings_visibility)

func toggle_settings() -> void:
	if is_instance_valid(game.nutrition):
		game.nutrition.close_cooking()
	close_storage()
	if settings.visible:close_settings()
	else:
		bag.hide();close_dialog()
		settings.show()

func _settings_visibility() -> void:
	if not settings.visible:
		settings.scale=Vector2.ONE
		settings_closing=false
		return
	if settings_tween and settings_tween.is_valid():settings_tween.kill()
	var viewport_size:=get_viewport().get_visible_rect().size
	var dimensions:=Vector2(minf(860,viewport_size.x-32),minf(650,viewport_size.y-24))
	settings.set_anchors_preset(Control.PRESET_CENTER)
	settings.offset_left=-dimensions.x*.5;settings.offset_right=dimensions.x*.5
	settings.offset_top=-dimensions.y*.5;settings.offset_bottom=dimensions.y*.5
	settings.pivot_offset=dimensions*.5
	settings.scale=Vector2(.055,1.0)
	settings_content.modulate.a=0.0
	settings_closing=false
	settings_tween=create_tween().set_parallel(true)
	settings_tween.tween_property(settings,"scale:x",1.0,.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	settings_tween.tween_property(settings_content,"modulate:a",1.0,.22).set_delay(.16)

func close_settings() -> void:
	if not settings.visible or settings_closing:return
	settings_closing=true
	if settings_tween and settings_tween.is_valid():settings_tween.kill()
	settings_tween=create_tween()
	settings_tween.tween_property(settings_content,"modulate:a",0.0,.08)
	settings_tween.tween_property(settings,"scale:x",.055,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	settings_tween.tween_callback(settings.hide)

func _build_dialog() -> void:
	dialog=centered_panel(Vector2(720,390))
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",14)
	dialog.add_child(column)
	var header:=HBoxContainer.new();column.add_child(header)
	speaker=Label.new();speaker.add_theme_font_size_override("font_size",24);speaker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(speaker)
	dialog_close=button("离开交谈  ×",close_dialog);dialog_close.add_theme_font_size_override("font_size",15);header.add_child(dialog_close)
	speech=RichTextLabel.new();speech.bbcode_enabled=true;speech.custom_minimum_size=Vector2(650,150);speech.fit_content=true;column.add_child(speech)
	choices_scroll = ScrollContainer.new()
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(choices_scroll)
	choices=VBoxContainer.new();choices.add_theme_constant_override("separation",8)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_scroll.add_child(choices)

func show_dialog(title:String,text:String,options:Array) -> void:
	if is_instance_valid(game.nutrition):
		game.nutrition.close_cooking()
	reading_letter = false
	if letter_tween and letter_tween.is_valid():
		letter_tween.kill()
	dialog.scale = Vector2.ONE
	dialog.modulate.a = 1.0
	close_storage()
	if game.survival != null:
		game.survival.hide_map()
	fishing.set_active(false)
	bag.hide();settings.hide()
	speaker.text=title
	speech.text=text
	var viewport_size:=get_viewport().get_visible_rect().size
	var width:=minf(800,viewport_size.x-40)
	var text_height:=260.0 if text.length()>250 else 82.0
	speech.fit_content=false
	speech.custom_minimum_size=Vector2(width-72,text_height)
	var height:=minf(viewport_size.y-48,text_height+110.0+options.size()*55.0)
	choices_scroll.custom_minimum_size.y = minf(options.size() * 55.0, maxf(80.0, viewport_size.y - text_height - 250.0))
	choices_scroll.scroll_vertical = 0
	dialog.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dialog.custom_minimum_size=Vector2(width,height)
	dialog.offset_left=-width*.5;dialog.offset_right=width*.5
	dialog.offset_top=-height-24;dialog.offset_bottom=-24
	dialog_close.visible=not game.dead
	dialog_close.text="收好信件  ×" if "信" in title else "离开交谈  ×"
	for child in choices.get_children():choices.remove_child(child);child.queue_free()
	for option:Dictionary in options:
		var choice:=button(option.text,option.action)
		choice.disabled=bool(option.get("disabled",false))
		choices.add_child(choice)
	dialog.show()
	_fit_dialog.call_deferred(width,height)
	game.player.controls_locked=true

func show_letter(text: String) -> void:
	show_dialog("窗边的信 · 岑安", text, [{"text":"把信收好","action":close_dialog}])
	reading_letter = true
	var dimensions := get_viewport().get_visible_rect().size
	var width := minf(840.0, dimensions.x - 48.0)
	var height := minf(650.0, dimensions.y - 48.0)
	speech.custom_minimum_size = Vector2(width - 72, height - 180)
	speech.scroll_active = true
	speech.scroll_to_line(0)
	choices_scroll.custom_minimum_size.y = 48
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.custom_minimum_size = Vector2(width, height)
	_fit_dialog(width, height)
	dialog.pivot_offset = Vector2(width, height) * .5
	dialog.scale = Vector2(.94, .65)
	dialog.modulate.a = .1
	letter_tween = create_tween().set_parallel(true)
	letter_tween.tween_property(dialog, "scale", Vector2.ONE, .24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	letter_tween.tween_property(dialog, "modulate:a", 1.0, .18)

func _fit_dialog(width:float,height:float) -> void:
	if not dialog.visible:return
	var dimensions:=get_viewport().get_visible_rect().size
	if reading_letter:
		width = minf(840.0, dimensions.x - 32.0)
	width=minf(width,dimensions.x-32)
	height=minf(maxf(height,dialog.get_combined_minimum_size().y),dimensions.y-32)
	dialog.offset_left=-width*.5;dialog.offset_right=width*.5
	if reading_letter:
		height = minf(650.0, dimensions.y - 32.0)
		dialog.offset_top = -height * .5
		dialog.offset_bottom = height * .5
	else:
		dialog.offset_top=-height-16;dialog.offset_bottom=-16

func close_dialog() -> void:
	dialog.hide()
	game.stop_talking()
	game.player.controls_locked=bag.visible or settings.visible or game.cinematic_active or game.dead

func _build_bag() -> void:
	var old:Control=fishing.inventory
	old.queue_free()
	bag=centered_panel(Vector2(1000,560))
	bag.offset_top = -320
	bag.offset_bottom = 240
	fishing.inventory=bag
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",12);bag.add_child(column)
	var header:=HBoxContainer.new();column.add_child(header)
	bag_summary=Label.new();bag_summary.add_theme_font_size_override("font_size",24);bag_summary.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(bag_summary)
	header.add_child(button("背包  B",func():open_character("bag")))
	header.add_child(button("人物状态",func():open_character("skills")))
	header.add_child(button("关闭  Esc",func():bag.hide()))
	inventory_content = VBoxContainer.new()
	inventory_content.add_theme_constant_override("separation", 12)
	inventory_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(inventory_content)
	var body:=HBoxContainer.new();body.add_theme_constant_override("separation",18);inventory_content.add_child(body)
	bag_grid=GridContainer.new();bag_grid.columns=4;bag_grid.add_theme_constant_override("h_separation",8);bag_grid.add_theme_constant_override("v_separation",8);body.add_child(bag_grid)
	var details:=VBoxContainer.new();details.custom_minimum_size.x=200;body.add_child(details)
	bag_detail=RichTextLabel.new();bag_detail.bbcode_enabled=true;bag_detail.custom_minimum_size=Vector2(200,280);details.add_child(bag_detail)
	bag_action=button("使用",func():pass);details.add_child(bag_action);bag_action.hide()
	var footer:=HBoxContainer.new();inventory_content.add_child(footer)
	footer.add_child(button("上一页",func():bag_page=maxi(0,bag_page-1);refresh_bag()))
	page_label=Label.new();page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;page_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(page_label)
	footer.add_child(button("下一页",func():bag_page=mini(maxi(0,(bag_entries.size()-1)/8),bag_page+1);refresh_bag()))
	character_content = HBoxContainer.new()
	character_content.add_theme_constant_override("separation", 20)
	character_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(character_content)
	var portrait = preload("res://scripts/ui/live_item_preview.gd").new()
	character_content.add_child(portrait)
	portrait.setup(load("res://assets/characters/C01_locomotion.glb").instantiate(), false, "Idle")
	portrait.custom_minimum_size = Vector2(210, 360)
	character_stats = RichTextLabel.new()
	character_stats.bbcode_enabled = true
	character_stats.custom_minimum_size = Vector2(610, 390)
	character_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
	character_content.add_child(character_stats)
	character_content.hide()

func open_character(page := "skills") -> void:
	if is_instance_valid(game.nutrition):
		game.nutrition.close_cooking()
	if game.cinematic_active or game.dead:
		return
	close_storage()
	fishing.set_active(false)
	settings.hide()
	if game.survival != null:
		game.survival.hide_map()
	close_dialog()
	character_page = page
	inventory_content.visible = page == "bag"
	character_content.visible = page == "skills"
	bag.show()
	bag_summary.text = "小爱 · 人物"
	if page == "bag":
		refresh_bag()
	else:
		character_stats.text = game.skills.summary()
	game.player.controls_locked = true

func toggle_character() -> void:
	if bag.visible and character_page == "skills":
		bag.hide()
	else:
		open_character("skills")

func toggle_bag() -> void:
	if game.cinematic_active or game.dead:return
	if bag.visible and character_page == "bag":
		bag.hide()
	else:
		open_character("bag")

func open_storage() -> void:
	if is_instance_valid(game.nutrition):
		game.nutrition.close_cooking()
	if game.cinematic_active or game.dead:
		return
	fishing.set_active(false)
	bag.hide()
	settings.hide()
	game.survival.hide_map()
	close_dialog()
	if storage_view == null:
		storage_view = preload("res://scripts/ui/storage_view.gd").new()
		add_child(storage_view)
		storage_view.setup(game, self)
		storage_view.close_requested.connect(close_storage)
	storage_view.open()
	game.player.controls_locked = true

func close_storage() -> void:
	if storage_view != null:
		storage_view.invalidate_drag()
		storage_view.hide()
	if is_instance_valid(game.survival):
		game.survival.close_chest()

func refresh_bag() -> void:
	if bag_grid==null:return
	for child in bag_grid.get_children():child.queue_free()
	bag_entries=fishing.catches.duplicate()
	if game.progress.rod_found:
		bag_entries.append({"id":"fishing_rod","name":"鱼竿","count":1})
	for item:Dictionary in game.progress.get("goods",[]):
		if int(item.get("count",0))>0:bag_entries.append(item)
	bag_page=clampi(bag_page,0,maxi(0,(bag_entries.size()-1)/8))
	bag_summary.text="小爱 · 人物"
	page_label.text="%d / %d"%[bag_page+1,maxi(1,ceili(bag_entries.size()/8.0))]
	bag_detail.text="背包 · %d 条鱼获\n\n按住工具图标或名称拖到下方装备栏，松开完成放置。\n\n点击装备栏或按数字键1–5快速装备，选中空槽收起工具。" % fishing.catches.size()
	bag_action.hide()
	for slot in 8:
		var card = preload("res://scripts/ui/tool_inventory_slot.gd").new()
		card.game = game
		card.custom_minimum_size = Vector2(146,185)
		card.add_theme_stylebox_override("panel",box(Color("e4d6b9"),10));bag_grid.add_child(card)
		var index:=bag_page*8+slot
		if index>=bag_entries.size():continue
		var item:Dictionary=bag_entries[index]
		card.item = item
		card.tooltip_text = "拖入下方工具栏可设置快捷工具" if game.hotbar.supports(str(item.id)) else str(item.name)
		var content:=VBoxContainer.new();card.add_child(content)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var is_fish:=item.has("species")
		var model:Node3D=fishing._fish_model(item) if is_fish else game.item_model(item)
		var preview=preload("res://scripts/ui/live_item_preview.gd").new();content.add_child(preview)
		preview.setup(model,is_fish,str(fishing.fish_definitions[item.species].clip) if is_fish else "")
		preview.custom_minimum_size = Vector2(128, 88)
		var text:String=item.name
		text+="\n%.2f kg"%float(item.weight_kg) if is_fish else " × "+str(int(item.get("count",1)))
		var select:=button(text,func():_select_item(item));select.add_theme_font_size_override("font_size",14);content.add_child(select)
		select.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if str(item.id).begins_with("delicious_dish_"):
			select.text = "选择  ×" + str(int(item.count))
			var name_label := RichTextLabel.new()
			name_label.bbcode_enabled = true
			name_label.fit_content = true
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_label.text = "[center]" + game.nutrition.display_name(item.id, item.name) + "[/center]"
			name_label.add_theme_font_size_override("normal_font_size", 14)
			content.add_child(name_label)
			content.move_child(name_label, 1)

func _select_item(item:Dictionary) -> void:
	for connection in bag_action.pressed.get_connections():bag_action.pressed.disconnect(connection.callable)
	if item.has("species"):
		bag_detail.text="%s\n\n重量  %.2f kg\n来自  %s\n\n可以带去码头，与闻舟交换物资。"%[item.name,float(item.weight_kg),"内湖" if item.get("habitat")=="lake" else "近海"]
		bag_action.hide()
	else:
		bag_detail.text=game.nutrition.display_name(item.id, item.name)+"\n\n"+game.item_description(item)
		bag_action.text="装备鱼叉  Q" if item.id in ["harpoon", "harpoon_steel"] else "选择种子  G"
		if item.id in game.farming.TOOLS:bag_action.text = "装备" + str(game.farming.TOOLS[item.id]) + "  X"
		if item.id in game.economy.CONSUMABLES:bag_action.text = "使用补给"
		if item.id == "lantern":bag_action.text = "开关便携灯"
		if item.id in ["hunting_rifle", "bow"]:bag_action.text = "装备并进入瞄准"
		if item.id == "fishing_rod":bag_action.text = "装备鱼竿"
		if item.id == "wood":bag_action.text = "制作木箭 ×3"
		if game.nutrition.is_food(item.id):bag_action.text = "食用 · 恢复%d饱食度" % game.nutrition.food_value(item.id)
		if game.is_equipped(str(item.id)):bag_action.text = "收起" + str(item.name)
		bag_action.visible=item.id in ["harpoon", "harpoon_steel", "lantern"] or item.id in game.economy.CONSUMABLES or item.id in game.farming.TOOLS or str(item.id).begins_with("seed_")
		bag_action.visible = bag_action.visible or item.id in ["hunting_rifle", "bow", "wood", "fishing_rod"] or game.nutrition.is_food(item.id)
		bag_action.pressed.connect(func():bag.hide();game.use_item(item.id))

func _build_cinematic() -> void:
	cinematic_panel=Control.new();cinematic_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(cinematic_panel)
	fade=ColorRect.new();fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);fade.color=Color(0,0,0,0);fade.mouse_filter=Control.MOUSE_FILTER_IGNORE;cinematic_panel.add_child(fade)
	for top in [true,false]:
		var bar:=ColorRect.new();bar.color=Color(.025,.055,.055,.95)
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.offset_top=0 if top else -105;bar.offset_bottom=65 if top else 0
		cinematic_panel.add_child(bar)
	cinematic_title=Label.new();cinematic_title.theme=theme_pack;cinematic_title.add_theme_color_override("font_color",Color("fff4db"));cinematic_title.add_theme_font_size_override("font_size",42);cinematic_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER);cinematic_title.position=Vector2(-360,-110);cinematic_title.size=Vector2(720,150);cinematic_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cinematic_panel.add_child(cinematic_title)
	cinematic_caption=Label.new();cinematic_caption.theme=theme_pack;cinematic_caption.add_theme_color_override("font_color",Color("fff4db"));cinematic_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);cinematic_caption.offset_top=-85;cinematic_caption.offset_bottom=-20;cinematic_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cinematic_caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;cinematic_panel.add_child(cinematic_caption)
	intro_buttons=HBoxContainer.new();intro_buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER);intro_buttons.position=Vector2(-160,65);cinematic_panel.add_child(intro_buttons)
	intro_buttons.add_child(button("开始旅程",func():game.opening.play()))
	intro_buttons.add_child(button("跳过序章",func():game.opening.finish()))
	var skip:=button("跳过  Esc",func():game.opening.finish());skip.position=Vector2(20,15);cinematic_panel.add_child(skip)
	cinematic_panel.hide()

func notify(text:String,seconds:=3.0) -> void:
	toast_text.text=text;toast_time=seconds;toast.show()

func modal_open() -> bool:
	return bag.visible or settings.visible or dialog.visible or (storage_view != null and storage_view.visible) or (game.survival != null and game.survival.map_open()) or (is_instance_valid(game.nutrition) and game.nutrition.ui_panel != null and game.nutrition.ui_panel.visible)

func _input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		if game.dead:get_viewport().set_input_as_handled();return
		if is_instance_valid(game.nutrition) and game.nutrition.ui_panel.visible:
			game.nutrition.close_cooking()
			get_viewport().set_input_as_handled()
			return
		if game.survival != null and game.survival.map_open():
			game.survival.toggle_map()
			get_viewport().set_input_as_handled()
			return
		if game.cinematic_active:
			if cinematic_panel.visible:
				game.opening.finish()
		elif storage_view != null and storage_view.visible:close_storage()
		elif bag.visible:bag.hide()
		elif dialog.visible:close_dialog()
		elif settings.visible:close_settings()
		elif fishing.player.fishing_active:fishing.set_active(false)
		else:toggle_settings()
		get_viewport().set_input_as_handled()

func _process(delta:float) -> void:
	toast_time=maxf(0,toast_time-delta);toast.visible=toast_time>0 and not game.cinematic_active and not modal_open()
	flash.color.a=move_toward(flash.color.a,0.,delta*.5)
	game.player.controls_locked=modal_open() or game.cinematic_active or game.dead or (game.vehicle != null and game.vehicle.entering)
	clock_button.text="第 %d 日 · %02d:%02d · %s%s"%[game.day_count,int(game.weather.hour),int(fmod(game.weather.hour,1.)*60),game.weather.WEATHER_NAMES[game.weather.current_weather],"  ×"+str(game.time_scale) if game.time_scale>1 else ""]
	clock_button.visible=not game.cinematic_active
	if bag.visible and character_page == "skills":
		var summary: String = game.skills.summary()
		if character_stats.text != summary:
			character_stats.text = summary
	top_controls.visible=not game.cinematic_active and not game.dead
	clock_button.disabled=game.dead
	letter_button.visible=bool(game.progress.letter_read)
	if settings.visible and not weather_choices.get_popup().visible:weather_choices.select(game.weather.current_weather)
	context_row.visible=not modal_open() and not game.cinematic_active and not game.dead
	water_hint.visible = context_row.visible and game.player.swimming
	context_button.visible=not game.context_text.is_empty()
	context_button.text=game.context_text
	fishing_button.visible=game.can_offer_fishing()
	fishing_button.text="F  收竿" if game.player.fishing_active else "F  钓鱼"
	spear_button.visible=game.has_good("harpoon") and game.player.swimming
	spear_button.text="Q  收起鱼叉" if game.harpoon_equipped else "Q  鱼叉"
	seed_button.visible=not game.selected_seed.is_empty() and game.has_good(game.selected_seed) and not game.player.swimming and not game.player.rowing.boarded and game.player.global_position.y>1.4
	tool_button.visible = game.farming.has_tools() and not game.player.swimming and not game.player.rowing.boarded
	if game.player.in_vehicle():
		tool_button.hide()
		seed_button.hide()
	seed_button.disabled = game.farming.action_cooldown > 0
	tool_button.text = "X  " + str(game.farming.TOOLS.get(game.farming.selected_tool, "选择工具"))
	context_row.reset_size()
	context_row.position.x = (get_viewport().get_visible_rect().size.x - context_row.size.x) * .5
	context_row.position.y = get_viewport().get_visible_rect().size.y - (182 if game.player.swimming else 150)
	fishing.panel.hide()
	fish_panel.visible=game.player.fishing_active and not modal_open() and not game.cinematic_active
	fish_text.text=fishing.prompt.text
	progress_bar.get_parent().visible=fishing.state==fishing.State.REELING
	progress_bar.value=fishing.progress*100
	tension_bar.value=fishing.tension*100
	tension_bar.modulate=Color(1,.45,.35) if fishing.tension>.75 else Color.WHITE
