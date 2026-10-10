class_name RustSound
extends Node

var sounds: Dictionary = {}
var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.max_polyphony = 8
	player.volume_db = -16
	add_child(player)
	for id in ["hit", "loot", "door", "heal", "death", "swing", "guard", "break", "phase", "hurt"]:
		var stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		var bytes = PackedByteArray()
		bytes.resize(8800)
		var frequency: float = {"hit": 110, "loot": 740, "door": 220, "heal": 520, "death": 65, "swing": 180, "guard": 980, "break": 85, "phase": 48, "hurt": 145}[id]
		for i in 4400:
			var t = i / 22050.0
			var envelope = pow(1.0 - i / 4400.0, 3)
			var value = sin(TAU * frequency * t * (1.0 + t * (2 if id == "loot" else -1)))
			bytes.encode_s16(i * 2, int(value * envelope * 22000))
		stream.data = bytes
		sounds[id] = stream

func play(id: String) -> void:
	if DisplayServer.get_name() == "headless": return
	player.stream = sounds[id]
	player.play()

func _exit_tree() -> void:
	player.stop()
	player.stream = null
	sounds.clear()
