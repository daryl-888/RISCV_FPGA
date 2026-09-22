"""Convert a little-endian RV32 instruction binary to a $readmemh image."""
import argparse
from pathlib import Path


def encode(data: bytes, depth: int = 256, image_format: str = "words") -> str:
    """Depth is always in 32-bit words. Unused instruction slots contain NOP."""
    if depth < 1:
        raise ValueError("depth must be positive")
    if not data or len(data) % 4:
        raise ValueError("input must contain a nonempty whole number of 32-bit instructions")
    if len(data) > depth * 4:
        raise ValueError("program exceeds instruction memory capacity")
    if image_format not in ("words", "bytes"):
        raise ValueError("format must be words or bytes")
    padded = data + bytes.fromhex("13000000") * (depth - len(data) // 4)
    if image_format == "bytes":
        return "".join(f"{byte:02x}\n" for byte in padded)
    return "".join(f"{int.from_bytes(padded[i:i+4], 'little'):08x}\n"
                   for i in range(0, len(padded), 4))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--depth", type=int, default=256, help="memory depth in 32-bit words")
    parser.add_argument("--format", choices=("words", "bytes"), default="words")
    args = parser.parse_args()
    try:
        text = encode(args.input.read_bytes(), args.depth, args.format)
    except (ValueError, OSError) as error:
        parser.error(str(error))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(text, encoding="ascii")


if __name__ == "__main__":
    main()
