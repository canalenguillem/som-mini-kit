class_name FakeOnline
extends RefCounted
## Dobles de prueba para OnlineClient: un WebSocket falso y un HTTP falso.


class Socket extends RefCounted:
	var handshake_headers: PackedStringArray = []
	var url: String = ""
	var state: int = WebSocketPeer.STATE_CONNECTING
	var inbox: Array[String] = []
	var sent: Array[Dictionary] = []
	var close_code: int = -1
	var open_after_polls: int = 1
	var _polls: int = 0

	func connect_to_url(u: String) -> int:
		url = u
		return OK

	func poll() -> void:
		_polls += 1
		if state == WebSocketPeer.STATE_CONNECTING and _polls >= open_after_polls:
			state = WebSocketPeer.STATE_OPEN

	func get_ready_state() -> int:
		return state

	func get_available_packet_count() -> int:
		return inbox.size() if state == WebSocketPeer.STATE_OPEN else 0

	func get_packet() -> PackedByteArray:
		return inbox.pop_front().to_utf8_buffer()

	func send_text(text: String) -> int:
		sent.append(JSON.parse_string(text))
		return OK

	func close(_code: int = 1000, _reason: String = "") -> void:
		state = WebSocketPeer.STATE_CLOSED

	func get_close_code() -> int:
		return close_code

	## Ayudas de prueba
	func receive(message: Dictionary) -> void:
		inbox.append(JSON.stringify(message))

	func server_closes(code: int) -> void:
		close_code = code
		state = WebSocketPeer.STATE_CLOSED

	func sent_of(kind: String) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for m: Dictionary in sent:
			if m.get("t") == kind:
				out.append(m)
		return out


class Http extends RefCounted:
	## ruta → respuesta {status, data}; se usa la primera que coincida con el final de la URL
	var responses: Dictionary = {}
	var calls: Array[Dictionary] = []

	func call_it(method: int, url: String, headers: PackedStringArray, body: String) -> Dictionary:
		calls.append({"method": method, "url": url, "headers": headers, "body": JSON.parse_string(body)})
		for path: String in responses:
			if url.ends_with(path):
				return responses[path]
		return {"status": 0, "data": {}}
