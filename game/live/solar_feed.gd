extends Node
## Latest NASA SDO browse imagery for educational display, never model inputs.
signal changed
const SOURCE_URL := "https://sdo.gsfc.nasa.gov/assets/img/latest/latest_512_0193.jpg"
const SOURCE_PAGE_URL := "https://sdo.gsfc.nasa.gov/data/"
const POLICY_URL := "https://sdo.gsfc.nasa.gov/data/rules.php"
const CREDIT := "Courtesy of NASA/SDO and the AIA, EVE, and HMI science teams."
const FALLBACK := "res://assets/nasa/sdo-aia-193-fallback.jpg"
const PROVENANCE := "res://assets/nasa/sdo-aia-193-provenance.json"
const MAX_BYTES := 2 * 1024 * 1024
const AUTO_INTERVAL_MS := 15 * 60 * 1000
const MANUAL_INTERVAL_MS := 60 * 1000
const STALE_SECONDS := 24 * 60 * 60
var _cache_root := "user://nasa-sdo"
var _status := "fallback"
var _source_kind := "bundled"
var _texture: Texture2D
var _message := "Bundled NASA image. Connect to check the latest available image."
var _last_checked := ""
var _last_success := 0.0
var _published := ""
var _published_unix := 0.0
var _hash := ""
var _last_attempt_ticks := -1
var _connected := false
var _http_status := 0
var _received_bytes := 0
var _request: HTTPRequest

func _init(cache_directory := "user://nasa-sdo") -> void:
	# An overridable single user-data subdirectory keeps tests isolated. There is
	# no URL or absolute filesystem path override in the production client.
	var expression := RegEx.create_from_string("^user://[a-z0-9-]{1,64}$")
	if expression.search(cache_directory): _cache_root = cache_directory

func _ready() -> void:
	_load_fallback()
	_load_cache()
	changed.emit()

static func _utc(unix: float) -> String:
	return Time.get_datetime_string_from_unix_time(int(unix), false) + "Z" if unix > 0 else ""

static func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func publication_time(value: String) -> float:
	# HTTP Last-Modified is publication metadata, not an observation timestamp.
	var expression := RegEx.create_from_string("^(Mon|Tue|Wed|Thu|Fri|Sat|Sun), ([0-9]{2}) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) ([0-9]{4}) ([0-9]{2}):([0-9]{2}):([0-9]{2}) GMT$")
	var found := expression.search(value)
	if not found: return 0.0
	var month := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"].find(found.get_string(3)) + 1
	var stamp := {"year": int(found.get_string(4)), "month": month, "day": int(found.get_string(2)), "hour": int(found.get_string(5)), "minute": int(found.get_string(6)), "second": int(found.get_string(7))}
	if stamp.year < 2000 or stamp.year > 2100 or stamp.day < 1 or stamp.day > 31 or stamp.hour > 23 or stamp.minute > 59 or stamp.second > 59: return 0.0
	var days := [31, 29 if stamp.year % 4 == 0 and (stamp.year % 100 != 0 or stamp.year % 400 == 0) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if stamp.day > days[month - 1]: return 0.0
	var unix := float(Time.get_unix_time_from_datetime_dict(stamp))
	var normalized := Time.get_datetime_dict_from_unix_time(int(unix))
	for field in stamp:
		if normalized[field] != stamp[field]: return 0.0
	return unix

static func jpeg_dimensions(bytes: PackedByteArray) -> Vector2i:
	# Read SOF dimensions before decoding, preventing an oversized decoded image
	# from allocating unbounded memory despite a small compressed HTTP body.
	if bytes.size() < 4 or bytes.size() > MAX_BYTES or bytes[0] != 0xff or bytes[1] != 0xd8 or bytes[-2] != 0xff or bytes[-1] != 0xd9: return Vector2i.ZERO
	var index := 2
	while index + 3 < bytes.size():
		if bytes[index] != 0xff: return Vector2i.ZERO
		while index < bytes.size() and bytes[index] == 0xff: index += 1
		if index >= bytes.size(): return Vector2i.ZERO
		var marker := bytes[index]
		index += 1
		if marker in [0xd8, 0xd9, 0xda, 0x00]: return Vector2i.ZERO
		if marker == 0x01 or (marker >= 0xd0 and marker <= 0xd7): continue
		if index + 1 >= bytes.size(): return Vector2i.ZERO
		var length := int(bytes[index]) * 256 + int(bytes[index + 1])
		if length < 2 or index + length > bytes.size(): return Vector2i.ZERO
		if marker in [0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf]:
			if length < 8: return Vector2i.ZERO
			return Vector2i(int(bytes[index + 5]) * 256 + int(bytes[index + 6]), int(bytes[index + 3]) * 256 + int(bytes[index + 4]))
		index += length
	return Vector2i.ZERO

static func validated_image(bytes: PackedByteArray) -> Image:
	if jpeg_dimensions(bytes) != Vector2i(512, 512): return null
	var decoded := Image.new()
	if decoded.load_jpg_from_buffer(bytes) != OK or decoded.get_size() != Vector2i(512, 512): return null
	return decoded

func snapshot() -> Dictionary:
	var now := Time.get_unix_time_from_system()
	var age := maxf(0.0, now - _last_success) if _last_success > 0 else -1.0
	var image_age := maxf(0.0, now - _published_unix) if _published_unix > 0 else -1.0
	var status := _status
	if status == "live" and image_age > STALE_SECONDS: status = "stale"
	return {"status": status, "texture": _texture, "source_url": SOURCE_URL, "source_page_url": SOURCE_PAGE_URL, "policy_url": POLICY_URL,
		"last_checked_utc": _last_checked, "last_success_utc": _utc(_last_success), "fetched_at_utc": _utc(_last_success), "file_updated_utc": _published,
		"cache_age_seconds": age, "image_age_seconds": image_age, "is_live": _connected and status in ["live", "stale"], "source_kind": _source_kind,
		"message": _message, "credit": CREDIT, "sha256": _hash, "width": 512 if _texture else 0, "height": 512 if _texture else 0,
		"stale": image_age > STALE_SECONDS, "busy": is_instance_valid(_request), "http_status": _http_status, "received_bytes": _received_bytes}

func _now_ticks() -> int:
	return Time.get_ticks_msec()

func refresh(force := false) -> void:
	if is_instance_valid(_request): return
	var ticks := _now_ticks()
	var interval := MANUAL_INTERVAL_MS if force else AUTO_INTERVAL_MS
	if _last_attempt_ticks >= 0 and ticks - _last_attempt_ticks < interval:
		if force:
			_message = "Please wait one minute between checks. The last available image stays here."
			changed.emit()
		return
	_last_attempt_ticks = ticks
	_last_checked = _utc(Time.get_unix_time_from_system())
	_status = "loading"
	_connected = false
	_message = "Checking NASA for its latest available solar image…"
	_request = _make_request()
	_request.timeout = 12.0
	_request.body_size_limit = MAX_BYTES
	_request.max_redirects = 0
	_request.accept_gzip = false
	add_child(_request)
	_request.request_completed.connect(_completed.bind(_request), CONNECT_ONE_SHOT)
	changed.emit()
	var error := _request.request(SOURCE_URL, ["Accept: image/jpeg"])
	if error != OK:
		_request.queue_free()
		_request = null
		_failed("NASA could not be reached. Showing the last available image.")

func _make_request() -> HTTPRequest:
	# A probe may subclass this factory to configure its environment's verified
	# proxy/CA. Production always uses the operating system's trusted TLS roots.
	return HTTPRequest.new()

func _completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	if request != _request: return
	_request.queue_free()
	_request = null
	_accept_response(result, code, headers, body)

func _accept_response(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_http_status = code
	_received_bytes = body.size()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or body.size() > MAX_BYTES:
		_failed("NASA is unavailable right now. Showing the last available image; refresh later.")
		return
	var mime := ""
	var modified := ""
	for header in headers:
		var split := header.find(":")
		if split < 0: continue
		var name := header.substr(0, split).strip_edges().to_lower()
		var value := header.substr(split + 1).strip_edges()
		if name == "content-type": mime = value.split(";")[0].strip_edges().to_lower()
		if name == "last-modified" and value.length() <= 100: modified = value
	var decoded := validated_image(body) if mime == "image/jpeg" else null
	if decoded == null:
		_failed("NASA returned an image we could not verify. Keeping the last available image.")
		return
	_texture = ImageTexture.create_from_image(decoded)
	_hash = _sha256(body)
	_last_success = Time.get_unix_time_from_system()
	_published_unix = publication_time(modified)
	if _published_unix > _last_success + 300: _published_unix = 0.0
	_published = modified if _published_unix > 0 else ""
	_source_kind = "network"
	_connected = true
	_status = "live"
	_message = "NASA connected · latest available. This solar image does not set the Mars mission's radiation values."
	if _published_unix > 0 and _last_success - _published_unix > STALE_SECONDS:
		_status = "stale"
		_message = "NASA connected, but its latest image was published over 24 hours ago. Check the publication date."
	if not _save_cache(body): _message += " This device could not save an offline copy."
	changed.emit()

func _failed(message: String) -> void:
	_connected = false
	_status = "fallback" if _source_kind == "bundled" else "cached"
	_message = message
	changed.emit()

func _safe_directory(create := false) -> bool:
	var user := DirAccess.open("user://")
	if user == null or user.is_link(_cache_root.trim_prefix("user://")): return false
	if create and DirAccess.make_dir_recursive_absolute(_cache_root) != OK: return false
	return DirAccess.dir_exists_absolute(_cache_root)

func _safe_file(name: String) -> bool:
	var directory := DirAccess.open(_cache_root)
	return directory != null and not directory.is_link(name) and not directory.dir_exists(name)

func _read_bytes(path: String, limit: int) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > limit: return PackedByteArray()
	return file.get_buffer(file.get_length())

func _load_fallback() -> void:
	# Exported games load the imported Texture2D. Source runs can also validate
	# raw JPEG bytes; cache and network images always pass the bounded decoder.
	var decoded := validated_image(_read_bytes(FALLBACK, MAX_BYTES))
	_texture = ImageTexture.create_from_image(decoded) if decoded else load(FALLBACK) as Texture2D
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROVENANCE))
	if parsed is Dictionary and parsed.get("source_url") == SOURCE_URL:
		_published = str(parsed.get("file_updated_utc", ""))
		_published_unix = publication_time(_published)
		_hash = str(parsed.get("sha256", ""))

func _load_cache() -> void:
	if not _safe_directory() or not _safe_file("latest.json"): return
	var bytes := _read_bytes(_cache_root.path_join("latest.json"), 8192)
	if bytes.is_empty(): return
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("schema") != 1 or parsed.get("source_url") != SOURCE_URL: return
	var checksum: Variant = parsed.get("sha256")
	var fetched: Variant = parsed.get("fetched_unix")
	var modified: Variant = parsed.get("file_updated_utc")
	if not checksum is String or RegEx.create_from_string("^[0-9a-f]{64}$").search(checksum) == null or not (fetched is float or fetched is int) or not modified is String or modified.length() > 100: return
	if not is_finite(float(fetched)) or fetched <= 0 or fetched > Time.get_unix_time_from_system() + 300: return
	var filename: String = checksum + ".jpg"
	if not _safe_file(filename): return
	bytes = _read_bytes(_cache_root.path_join(filename), MAX_BYTES)
	if bytes.is_empty() or _sha256(bytes) != checksum: return
	var decoded := validated_image(bytes)
	if decoded == null: return
	_texture = ImageTexture.create_from_image(decoded)
	_hash = checksum
	_last_success = float(fetched)
	_published_unix = publication_time(modified)
	_published = modified if _published_unix > 0 and _published_unix <= _last_success + 300 else ""
	if _published.is_empty(): _published_unix = 0.0
	_status = "cached"
	_source_kind = "cache"
	_message = "Saved NASA image. Connect to check the latest available image."

func _atomic_write(name: String, bytes: PackedByteArray) -> bool:
	if not _safe_file(name) or not _safe_file(name + ".tmp"): return false
	var path := _cache_root.path_join(name)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func _save_cache(bytes: PackedByteArray) -> bool:
	if not _safe_directory(true): return false
	# Publish an immutable content-addressed blob before atomically replacing its
	# pointer. An interrupted write can never bless partial JPEG bytes as current.
	if not _atomic_write(_hash + ".jpg", bytes): return false
	var record := {"schema": 1, "source_url": SOURCE_URL, "sha256": _hash, "fetched_unix": _last_success, "file_updated_utc": _published}
	if not _atomic_write("latest.json", JSON.stringify(record).to_utf8_buffer()): return false
	var directory := DirAccess.open(_cache_root)
	for filename in directory.get_files():
		if filename != _hash + ".jpg" and RegEx.create_from_string("^[0-9a-f]{64}\\.jpg$").search(filename) and _safe_file(filename):
			directory.remove(filename)
	return true
