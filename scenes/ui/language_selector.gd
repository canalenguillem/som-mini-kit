class_name LanguageSelector
extends OptionButton
## Desplegable de idioma. Muestra cada idioma con su propio nombre y lo aplica al momento.


func _ready() -> void:
	clear()
	for loc: String in GameState.LOCALES:
		add_item("LANG_" + loc.to_upper())
		set_item_metadata(item_count - 1, loc)
	_select_current()
	item_selected.connect(_on_item_selected)
	Events.locale_changed.connect(func(_l: String) -> void: _select_current())


func _select_current() -> void:
	select(GameState.LOCALES.find(GameState.locale))


func _on_item_selected(index: int) -> void:
	GameState.set_locale(str(get_item_metadata(index)))
