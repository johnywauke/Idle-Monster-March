class_name Numbers
extends RefCounted

# Formatacao de numeros grandes (K, M, B, T, aa, ab...).
# NOTA: o armazenamento usa float/double, que aguenta ate ~fase 5000 antes de
# estourar. Para "progressao infinita" de verdade (v2), o caminho de upgrade e
# trocar o storage por um BigNumber (mantissa + expoente). A formatacao ja esta pronta.

const SUFFIXES := ["", "K", "M", "B", "T", "aa", "ab", "ac", "ad", "ae", "af", "ag", "ah", "ai", "aj"]

static func format(value: float) -> String:
	if is_inf(value):
		return "INF"
	if value <= 0.0:
		return "0"
	if value < 1000.0:
		if value == floor(value):
			return str(int(value))
		return "%.1f" % value
	var tier := int(floor(log(value) / log(1000.0)))
	tier = clampi(tier, 0, SUFFIXES.size() - 1)
	var scaled := value / pow(1000.0, float(tier))
	return "%.2f%s" % [scaled, SUFFIXES[tier]]
