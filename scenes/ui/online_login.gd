class_name OnlineLogin
extends Control
## Entrar o registrarse en el servidor online. La contraseña nunca se guarda en el equipo.

const LOBBY_SCENE: String = "res://scenes/ui/online_lobby.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

var online: OnlineClient  ## se inyecta en las pruebas
var navigate: Callable = func(path: String) -> void: get_tree().change_scene_to_file(path)  ## las pruebas lo sustituyen
var _registering: bool = false

@onready var _title: Label = $Center/Box/Title
@onready var _user: LineEdit = $Center/Box/User
@onready var _email: LineEdit = $Center/Box/Email
@onready var _password: LineEdit = $Center/Box/Password
@onready var _password2: LineEdit = $Center/Box/Password2
@onready var _privacy: CheckBox = $Center/Box/Privacy
@onready var _privacy_link: Button = $Center/Box/PrivacyLink
@onready var _server: LineEdit = $Center/Box/Server
@onready var _message: Label = $Center/Box/Message
@onready var _submit: Button = $Center/Box/Submit
@onready var _switch: Button = $Center/Box/Switch
@onready var _resend: Button = $Center/Box/Resend
@onready var _forgot: Button = $Center/Box/Forgot
@onready var _back: Button = $Center/Box/Back


func _ready() -> void:
	if online == null:
		online = Online
	Music.play_menu()
	_user.text = online.username_hint
	_server.text = online.server_url
	_submit.pressed.connect(_on_submit)
	_switch.pressed.connect(func() -> void: _set_mode(not _registering))
	_resend.pressed.connect(_on_resend)
	_privacy_link.pressed.connect(func() -> void: OS.shell_open(online.web_url("/privacidad")))
	_forgot.pressed.connect(func() -> void: OS.shell_open(online.web_url("/olvide")))
	_back.pressed.connect(func() -> void: _go(MAIN_MENU_SCENE))
	_password.text_submitted.connect(func(_t: String) -> void: _on_submit())
	_password2.text_submitted.connect(func(_t: String) -> void: _on_submit())
	if online.is_logged_in():
		_go.call_deferred(LOBBY_SCENE)
		return
	_set_mode(false)
	(_user if _user.text.is_empty() else _password).grab_focus()


func _set_mode(registering: bool) -> void:
	_registering = registering
	_title.text = "Crear cuenta" if registering else "Entrar al modo online"
	_email.visible = registering
	_password2.visible = registering
	_privacy.visible = registering
	_privacy_link.visible = registering
	_forgot.visible = not registering
	_resend.visible = false
	_submit.text = "Registrarme" if registering else "Entrar"
	_switch.text = "Ya tengo cuenta" if registering else "Crear cuenta nueva"
	_say("")


func _say(text: String, is_error: bool = false) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if is_error else Color(0.5, 0.9, 0.55))


func _busy(value: bool) -> void:
	_submit.disabled = value
	_switch.disabled = value


func _on_submit() -> void:
	online.server_url = _server.text.strip_edges().trim_suffix("/")
	_busy(true)
	_say("Conectando…")
	if _registering:
		await _do_register()
	else:
		await _do_login()
	_busy(false)


func _do_login() -> void:
	var res: Dictionary = await online.login(_user.text, _password.text)
	if res["ok"]:
		_go(LOBBY_SCENE)
		return
	_say(res["message"], true)
	_resend.visible = res["code"] == "not_activated"


func _do_register() -> void:
	if _password.text != _password2.text:
		_say("Las contraseñas no coinciden.", true)
		return
	if not _privacy.button_pressed:
		_say("Para crear la cuenta tienes que aceptar la política de privacidad.", true)
		return
	var res: Dictionary = await online.register(_user.text, _email.text, _password.text, true)
	if res["ok"]:
		_set_mode(false)
		_say("Cuenta creada. Te hemos enviado un correo: abre el enlace para activarla y luego entra.")
		_password.text = ""
	else:
		_say(res["message"], true)


func _on_resend() -> void:
	var email: String = _email.text if not _email.text.is_empty() else _user.text
	if not email.contains("@"):
		_say("Escribe tu correo en el campo de usuario para reenviarte el enlace.", true)
		return
	var res: Dictionary = await online.resend_activation(email)
	_say("Si la cuenta existe y no está activada, te hemos enviado un enlace nuevo." if res["ok"] else res["message"], not res["ok"])


func _go(path: String) -> void:
	navigate.call(path)
