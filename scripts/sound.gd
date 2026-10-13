class_name Sound
extends RefCounted
# Short original synthesized cues, generated locally. No audio downloads.
static func play(parent: Node, frequency: float, duration := 0.12, end_frequency := -1.0, volume := -17.0) -> void:
	var sample_rate := 22050
	var data := PackedByteArray()
	var phase := 0.0
	var count := int(sample_rate*duration)
	data.resize(count*2)
	for i in count:
		var t := float(i)/count
		var hz := lerpf(frequency,frequency if end_frequency<0 else end_frequency,t)
		phase += TAU*hz/sample_rate
		var envelope := minf(t*25,1)*pow(1-t,1.8)
		var value := int((sin(phase)+sin(phase*2)*0.16)*envelope*20000)
		data.encode_s16(i*2,value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	var audio := AudioStreamPlayer.new()
	audio.stream = stream
	audio.volume_db = volume
	parent.add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
