extends Node

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	add_child(_player)
	_player.stream = _build_boink_stream()


func play_boink() -> void:
	_player.play()


func _build_boink_stream() -> AudioStreamWAV:
	var sample_rate := 44100
	var duration := 0.18
	var sample_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / float(sample_rate)
		var envelope := exp(-t * 18.0)
		var freq := 520.0 - t * 180.0
		var sample := sin(TAU * freq * t) * envelope * 0.35
		var int_sample := int(clampf(sample * 32767.0, -32767.0, 32767.0))
		data[i * 2] = int_sample & 0xFF
		data[i * 2 + 1] = (int_sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
