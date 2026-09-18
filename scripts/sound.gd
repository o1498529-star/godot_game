extends Node

var enabled := true
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var voice_index := 0

func _ready() -> void:
	for i in range(6):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -17
		add_child(voice)
		voices.append(voice)
	for key in ["coin", "jump", "crash", "power", "start"]:
		sounds[key] = make_tone(key)

func play(key: String) -> void:
	if not enabled or not sounds.has(key): return
	var voice := voices[voice_index % voices.size()]
	voice_index += 1
	voice.stream = sounds[key]
	voice.play()

func make_tone(key: String) -> AudioStreamWAV:
	var duration := 0.14 if key == "coin" else 0.3
	var frequencies := {"coin": 1100.0, "jump": 390.0, "crash": 95.0, "power": 700.0, "start": 520.0}
	var samples := int(22050 * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / 22050.0
		var progress := float(i) / samples
		var hz: float = frequencies[key]
		var wave := sin(TAU * hz * t * (1 + progress * 0.22))
		var envelope := minf(progress * 25, 1) * pow(1 - progress, 2)
		data.encode_s16(i * 2, int(wave * envelope * 15000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream
