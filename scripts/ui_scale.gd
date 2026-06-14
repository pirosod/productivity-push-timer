extends Node

const SCALE := 2.5
const BASE_FONT_SIZE := 16


static func scale(value: float) -> float:
	return value * SCALE


static func scale_i(value: int) -> int:
	return int(value * SCALE)


static func font_size(base: int = BASE_FONT_SIZE) -> int:
	return scale_i(base)


static func text_color() -> Color:
	return Color.WHITE if ProductivityData.is_session_active() else Color.BLACK
