class_name MissionShell
extends Control
## Marco común de las misiones: tres fases (ejemplo, guiado, en solitario), chuleta, pistas,
## nota e informe. Cada misión solo aporta su MissionContent.

const HUB: String = "res://scenes/hub/hub.tscn"
const Phase = MissionContent.Phase
const PHASE_KEYS: Array[String] = ["PHASE_EXAMPLE", "PHASE_GUIDED", "PHASE_SOLO"]
const INTRO_KEYS: Array[String] = ["PHASE_EXAMPLE_INTRO", "PHASE_GUIDED_INTRO", "PHASE_SOLO_INTRO"]

@export var mission: MissionData  ## si es null, se usa GameState.current_mission
@export var reports_dir: String = AttemptReport.DEFAULT_DIR

var exercise_seed: int = 0
var phase: Phase = Phase.EXAMPLE
var content: MissionContent
var failed_checks: int = 0  ## solo cuentan en la fase en solitario
var hints_used: int = 0  ## ídem
var grade: float = -1.0
var report: Dictionary = {}
var report_path: String = ""

var _hint_index: int = 0
var _solo_mistakes: Array[Dictionary] = []
var _started_unix: float = 0.0
var _started_ms: int = 0

@onready var _title: Label = $Margin/Box/Top/Title
@onready var _phase_label: Label = $Margin/Box/Top/Phase
@onready var _cheatsheet_button: Button = $Margin/Box/Top/Cheatsheet
@onready var _hint_button: Button = $Margin/Box/Top/Hint
@onready var _host: Control = $Margin/Box/Host
@onready var _feedback: RichTextLabel = $Margin/Box/FeedbackPanel/Feedback
@onready var _check: Button = $Margin/Box/Bottom/Check
@onready var _hand_in: Button = $Margin/Box/Bottom/HandIn
@onready var _next: Button = $Margin/Box/Bottom/Next
@onready var _cheatsheet: Control = $CheatsheetLayer
@onready var _cheatsheet_title: Label = $CheatsheetLayer/Panel/Box/Title
@onready var _cheatsheet_body: RichTextLabel = $CheatsheetLayer/Panel/Box/Body
@onready var _cheatsheet_close: Button = $CheatsheetLayer/Panel/Box/Close
@onready var _result: Control = $ResultLayer
@onready var _result_title: Label = $ResultLayer/Panel/Box/Title
@onready var _result_grade: Label = $ResultLayer/Panel/Box/Grade
@onready var _result_details: RichTextLabel = $ResultLayer/Panel/Box/Details
@onready var _retry: Button = $ResultLayer/Panel/Box/Buttons/Retry
@onready var _open_reports: Button = $ResultLayer/Panel/Box/Buttons/Reports
@onready var _to_hub: Button = $ResultLayer/Panel/Box/Buttons/Hub
@onready var _pause: PauseMenu = $PauseMenu


func _ready() -> void:
	if mission == null:
		mission = GameState.current_mission
	_cheatsheet.visible = false
	_result.visible = false
	_pause.quit_scene = HUB
	if mission == null or mission.content_scene.is_empty():
		push_error("MissionShell sin misión")
		return
	exercise_seed = GameState.take_seed()
	_title.text = mission.title_key
	content = (load(mission.content_scene) as PackedScene).instantiate() as MissionContent
	content.configure(mission.params)
	_host.add_child(content)
	_check.pressed.connect(check)
	_hand_in.pressed.connect(hand_in)
	_next.pressed.connect(next_phase)
	_hint_button.pressed.connect(show_hint)
	_cheatsheet_button.pressed.connect(toggle_cheatsheet)
	_cheatsheet_close.pressed.connect(toggle_cheatsheet)
	_retry.pressed.connect(retry)
	_open_reports.pressed.connect(func() -> void: OS.shell_open(ProjectSettings.globalize_path(reports_dir)))
	_to_hub.pressed.connect(func() -> void: get_tree().change_scene_to_file(HUB))
	Events.locale_changed.connect(func(_l: String) -> void: _refresh_dynamic_texts())
	_started_unix = Time.get_unix_time_from_system()
	_started_ms = Time.get_ticks_msec()
	start_phase(Phase.EXAMPLE)


func _unhandled_input(event: InputEvent) -> void:
	if _result.visible:
		return
	if event.is_action_pressed("cheatsheet"):
		toggle_cheatsheet()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hint") and not _hint_button.disabled:
		show_hint()
		get_viewport().set_input_as_handled()


## Semilla de cada fase: la de la fase en solitario es la del intento, la que se informa.
func seed_for(p: Phase) -> int:
	match p:
		Phase.EXAMPLE:
			return ExerciseSeed.derive(exercise_seed, "example")
		Phase.GUIDED:
			return ExerciseSeed.derive(exercise_seed, "guided")
	return exercise_seed


func start_phase(p: Phase) -> void:
	phase = p
	_hint_index = 0
	content.setup(p, seed_for(p))
	_set_feedback(tr(INTRO_KEYS[p]))
	_check.visible = p != Phase.EXAMPLE
	_hand_in.visible = p == Phase.SOLO
	_next.visible = p != Phase.SOLO
	_next.disabled = p == Phase.GUIDED
	_refresh_dynamic_texts()
	if p == Phase.EXAMPLE:
		_next.grab_focus()


func next_phase() -> void:
	if phase == Phase.EXAMPLE:
		start_phase(Phase.GUIDED)
	elif phase == Phase.GUIDED:
		start_phase(Phase.SOLO)


func check() -> void:
	if phase == Phase.EXAMPLE:
		return
	var r: ChallengeResult = content.check()
	if r.is_perfect():
		if phase == Phase.SOLO:
			finish(r)
		else:
			_set_feedback(tr("CHECK_OK_GUIDED"))
			_next.disabled = false
			_next.grab_focus()
		return
	if phase == Phase.SOLO:
		failed_checks += 1
		_solo_mistakes.append_array(r.mistakes)
	var text: String = tr("CHECK_WRONG").format({"correct": r.correct, "total": r.total})
	for m: String in r.messages():
		text += "\n• " + m
	_set_feedback(text)


## Entrega lo que haya, aunque no esté bien del todo.
func hand_in() -> void:
	if phase != Phase.SOLO:
		return
	var r: ChallengeResult = content.check()
	if not r.is_perfect():
		_solo_mistakes.append_array(r.mistakes)
	finish(r)


func show_hint() -> void:
	if phase == Phase.EXAMPLE or _hint_index >= content.hint_count():
		return
	var text: String = content.hint(_hint_index)
	_hint_index += 1
	if phase == Phase.SOLO:
		hints_used += 1
	_set_feedback("[b]%s[/b] %s" % [tr("HINT_PREFIX"), text])
	_update_hint_button()


func toggle_cheatsheet() -> void:
	_cheatsheet.visible = not _cheatsheet.visible
	if _cheatsheet.visible and mission.cheatsheet != null:
		_cheatsheet_title.text = mission.cheatsheet.title_key
		_cheatsheet_body.text = tr(mission.cheatsheet.body_key).replace("\\n", "\n")
		_cheatsheet_close.grab_focus()


func finish(r: ChallengeResult) -> void:
	var weights: GradingWeights = mission.weights if mission.weights != null else GradingWeights.new()
	grade = Grading.grade(r.correct, r.total, failed_checks, hints_used, content.hint_count(), weights)
	report = build_report(r, weights)
	report_path = AttemptReport.save(report, reports_dir)
	_show_result(r, weights)


func build_report(r: ChallengeResult, weights: GradingWeights) -> Dictionary:
	var mistakes: Array = []
	for m: Dictionary in _solo_mistakes:
		mistakes.append({"key": m["key"], "args": m["args"], "text": ChallengeResult.message_of(m)})
	return {
		"format": AttemptReport.FORMAT,
		"game": ProjectSettings.get_setting("application/config/name", ""),
		"student": GameState.student_name,
		"mission": mission.id,
		"topic": mission.topic,
		"criteria": Array(mission.criteria),
		"seed": exercise_seed,
		"mode": "practice",
		"grade": grade,
		"passed": Grading.passed(grade, weights),
		"correct": r.correct,
		"total": r.total,
		"failed_checks": failed_checks,
		"hints_used": hints_used,
		"hints_available": content.hint_count(),
		"duration_s": (Time.get_ticks_msec() - _started_ms) / 1000,
		"started_at": Time.get_datetime_string_from_unix_time(int(_started_unix)),
		"finished_at": Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system())),
		"locale": GameState.locale,
		"mistakes": mistakes,
	}


func retry() -> void:
	get_tree().reload_current_scene()


func _show_result(r: ChallengeResult, weights: GradingWeights) -> void:
	_cheatsheet.visible = false
	_result.visible = true
	var ok: bool = Grading.passed(grade, weights)
	_result_title.text = "RESULT_PASSED" if ok else "RESULT_FAILED"
	_result_grade.text = Grading.format_grade(grade, GameState.locale)
	var secs: int = int(report.get("duration_s", 0))
	var lines: PackedStringArray = [
		tr("RESULT_ACCURACY").format({"correct": r.correct, "total": r.total}),
		tr("RESULT_FAILED_CHECKS").format({"n": failed_checks}),
		tr("RESULT_HINTS").format({"used": hints_used, "total": content.hint_count()}),
		tr("RESULT_TIME").format({"time": "%d:%02d" % [secs / 60, secs % 60]}),
		tr("RESULT_SEED").format({"seed": exercise_seed}),
	]
	if not r.is_perfect():
		lines.append("")
		lines.append(tr("RESULT_LAST_MISTAKES"))
		for m: String in r.messages():
			lines.append("• " + m)
	lines.append("")
	lines.append(tr("RESULT_SAVED") if not report_path.is_empty() else tr("RESULT_NOT_SAVED"))
	_result_details.text = "\n".join(lines)
	_retry.grab_focus()


## Textos montados en código: se rehacen al cambiar de idioma (desde la pausa, por ejemplo).
func _refresh_dynamic_texts() -> void:
	_phase_label.text = tr("PHASE_LABEL").format({"n": int(phase) + 1, "name": tr(PHASE_KEYS[phase])})
	_update_hint_button()


func _update_hint_button() -> void:
	var left: int = maxi(content.hint_count() - _hint_index, 0)
	_hint_button.text = tr("HINT_BUTTON").format({"n": left})
	_hint_button.disabled = phase == Phase.EXAMPLE or left == 0


func _set_feedback(text: String) -> void:
	_feedback.text = text
