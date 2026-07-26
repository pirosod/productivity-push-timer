"""Extract the first cel from an Aseprite .aseprite file into a PNG."""
from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
	def chunk(tag: bytes, data: bytes) -> bytes:
		return (
			struct.pack(">I", len(data))
			+ tag
			+ data
			+ struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
		)

	raw = b"".join(b"\x00" + rgba[y * width * 4 : (y + 1) * width * 4] for y in range(height))
	png = (
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
		+ chunk(b"IDAT", zlib.compress(raw, 9))
		+ chunk(b"IEND", b"")
	)
	path.write_bytes(png)


def extract_aseprite(src: Path, dst: Path) -> None:
	data = src.read_bytes()
	if len(data) < 128:
		raise SystemExit(f"File too small: {src}")
	_file_size, magic, _frames, width, height, depth = struct.unpack_from("<IHHHHH", data, 0)
	if magic != 0xA5E0:
		raise SystemExit(f"Not an Aseprite file (magic={magic:#x}): {src}")
	if depth != 32:
		raise SystemExit(f"Only 32-bit RGBA sprites supported (got {depth} bpp)")

	pos = 128
	_frame_size, frame_magic, old_chunks, _duration, _pad, new_chunks = struct.unpack_from(
		"<IHHHHI", data, pos
	)
	if frame_magic != 0xF1FA:
		raise SystemExit(f"Bad frame magic: {frame_magic:#x}")
	chunk_count = new_chunks if old_chunks == 0xFFFF else old_chunks
	pos += 16

	rgba: bytes | None = None
	cel_w = cel_h = 0
	for _ in range(chunk_count):
		chunk_size, chunk_type = struct.unpack_from("<IH", data, pos)
		cdata = data[pos + 6 : pos + chunk_size]
		if chunk_type == 0x2005:  # Cel
			_layer, _x, _y, _opacity, cel_type = struct.unpack_from("<HhhBH", cdata, 0)
			payload = cdata[16:]
			if cel_type == 0:  # raw
				cel_w, cel_h = struct.unpack_from("<HH", payload, 0)
				rgba = payload[4 : 4 + cel_w * cel_h * 4]
			elif cel_type == 2:  # zlib
				cel_w, cel_h = struct.unpack_from("<HH", payload, 0)
				rgba = zlib.decompress(payload[4:])
			else:
				raise SystemExit(f"Unsupported cel type: {cel_type}")
		pos += chunk_size

	if rgba is None:
		raise SystemExit("No image cel found in Aseprite file")
	if len(rgba) < cel_w * cel_h * 4:
		raise SystemExit("Cel pixel data truncated")

	# Place cel into full canvas if needed (top-left for simple icons).
	if cel_w == width and cel_h == height:
		canvas = rgba[: width * height * 4]
	else:
		canvas = bytearray(width * height * 4)
		for y in range(min(cel_h, height)):
			src_off = y * cel_w * 4
			dst_off = y * width * 4
			row = rgba[src_off : src_off + min(cel_w, width) * 4]
			canvas[dst_off : dst_off + len(row)] = row
		canvas = bytes(canvas)

	write_png(dst, width, height, canvas)
	print(f"Wrote {dst} ({width}x{height})")


def main() -> None:
	root = Path(__file__).resolve().parents[1]
	src = root / "icon.aseprite"
	dst = root / "icon.png"
	if len(sys.argv) >= 2:
		src = Path(sys.argv[1])
	if len(sys.argv) >= 3:
		dst = Path(sys.argv[2])
	extract_aseprite(src, dst)


if __name__ == "__main__":
	main()
