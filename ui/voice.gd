extends AudioStreamPlayer

# Gibberish "speech": one short vowel blip per revealed word, at a random pitch.
# The blips are original, synthesized here at startup (no sound files, no network).
# They're plain AudioStreamWAVs, which the web build can play; one player is reused,
# so a new blip cuts the last one off instead of stacking voices.

const RATE = 22050
# Vowel formants (Hz): roughly "ah", "eh", "ee", "oh", "oo"
const VOWELS = {
	"a": [800, 1200], "e": [500, 1900], "i": [300, 2300], "o": [500, 900], "u": [330, 800],
}

@export var enabled := true
@export var base_db := -10.0          # quiet, so it sits under the music
@export var pitch_variation := 0.12   # +/- this much around each speaker's pitch
@export var blip_length := 0.09       # seconds per blip, before pitch changes it

var blips := {}   # vowel letter -> AudioStreamWAV
var setting := 1.0   # the menu's voice volume, 0 to 1

func _ready() -> void:
	for v in VOWELS:
		blips[v] = _make_blip(VOWELS[v][0], VOWELS[v][1])
	set_volume(setting)

# The blip uses the word's first vowel, so the "speech" follows the text a little
func speak(word: String, pitch: float) -> void:
	if not enabled or setting <= 0.0:
		return
	var vowel := ""
	var spoken := false   # "..." or a dash alone stays silent
	for c in word.to_lower():
		if c.is_valid_int() or c != c.to_upper():
			spoken = true
		if vowel == "" and c in VOWELS:
			vowel = c
	if not spoken:
		return
	if vowel == "":
		vowel = "a"
	stream = blips[vowel]
	var lift := 0.08 if word.ends_with("?") or word.ends_with("!") else 0.0   # questions and exclamations go up
	pitch_scale = pitch * (1.0 + lift + randf_range(-pitch_variation, pitch_variation))
	play()

func set_volume(linear: float) -> void:
	setting = linear
	volume_db = base_db + linear_to_db(maxf(linear, 0.0001))

# A buzzy voice at ~180 Hz shaped by two vowel formants, with a little pitch slide and a quick fade
func _make_blip(f1: float, f2: float) -> AudioStreamWAV:
	var count := int(blip_length * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for n in count:
		var t := float(n) / count
		var f0 := 180.0 * (1.0 + 0.15 * t)   # slides up a bit, like a syllable
		phase += TAU * f0 / RATE
		var s := 0.0
		for k in range(1, 20):
			var f := k * f0
			var amp := exp(-pow((f - f1) / 180.0, 2)) + 0.6 * exp(-pow((f - f2) / 260.0, 2))
			s += amp * sin(k * phase)
		var env := minf(t / 0.08, 1.0) * pow(1.0 - t, 1.5)   # short attack, smooth fade
		data.encode_s16(n * 2, int(clampf(s * env * 0.35, -1.0, 1.0) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
