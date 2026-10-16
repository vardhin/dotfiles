#!/usr/bin/env python3
"""dotwall-pi: the P10 wall's receiver, on the Raspberry Pi.

Listens for frames from Dot Shell (`dotwall`, services/Wall.qml) on UDP and
puts them on the panels. It draws nothing of its own: every frame is
rendered by the shell, in the era's colors.

Backends (--backend, default auto: the first that imports):
  rgbmatrix  hzeller/rpi-rgb-led-matrix Python bindings (its Pi 5 / PIO
             support included)
  piomatter  Adafruit's Pi 5 PIO driver (adafruit-blinka-raspberry-pi5-piomatter)
  term       truecolor blocks in this terminal: try it with no panels at all

Defaults are for a 2x2 wall of 32x16 P10 panels on one chain (64x32, a
U-mapper folding the chain into two rows). Frames of another size are
centered and cropped or padded. After --idle seconds without a frame the
wall goes dark.

  sudo ./dotwall-pi.py                                  2x2 P10, hzeller
  sudo ./dotwall-pi.py --multiplexing 1 --row-addr-type 0 --brightness 60
  ./dotwall-pi.py --backend term                        preview on any machine

Packet: b"DOTW", version 1, width and height (uint16 BE), width*height*3 RGB.
"""
import argparse, select, socket, sys, time

MAGIC = b"DOTW\x01"


class Term:
    """Two pixels per character cell (upper half block), truecolor."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        sys.stdout.write("\x1b[2J\x1b[?25l")

    def show(self, rgb):
        out = ["\x1b[H"]
        for y in range(0, self.h, 2):
            for x in range(self.w):
                a = (y * self.w + x) * 3
                b = ((y + 1) * self.w + x) * 3 if y + 1 < self.h else a
                out.append(f"\x1b[38;2;{rgb[a]};{rgb[a+1]};{rgb[a+2]}m\x1b[48;2;{rgb[b]};{rgb[b+1]};{rgb[b+2]}m▀")
            out.append("\x1b[0m\n")
        sys.stdout.write("".join(out))
        sys.stdout.flush()

    def close(self):
        sys.stdout.write("\x1b[0m\x1b[?25h\n")


class RgbMatrix:
    def __init__(self, a):
        from rgbmatrix import RGBMatrix, RGBMatrixOptions
        o = RGBMatrixOptions()
        o.rows, o.cols, o.chain_length, o.parallel = a.rows, a.cols, a.chain, a.parallel
        o.brightness = a.brightness
        o.hardware_mapping = a.hardware_mapping
        o.gpio_slowdown = a.slowdown
        o.multiplexing = a.multiplexing
        o.row_address_type = a.row_addr_type
        o.pwm_bits = a.pwm_bits
        o.pixel_mapper_config = a.mapper
        o.drop_privileges = False
        self.m = RGBMatrix(options=o)
        self.c = self.m.CreateFrameCanvas()
        self.w, self.h = self.c.width, self.c.height

    def show(self, rgb):
        c, w = self.c, self.w
        for y in range(self.h):
            row = y * w * 3
            for x in range(w):
                i = row + x * 3
                c.SetPixel(x, y, rgb[i], rgb[i + 1], rgb[i + 2])
        self.c = self.m.SwapOnVSync(c)

    def close(self):
        self.m.Clear()


class PioMatter:
    def __init__(self, a):
        import numpy as np
        import adafruit_blinka_raspberry_pi5_piomatter as pm
        self.np = np
        self.w, self.h = a.width, a.height
        geo = pm.Geometry(width=self.w, height=self.h, n_addr_lines=a.addr_lines, rotation=pm.Orientation.Normal)
        self.fb = np.zeros((self.h, self.w, 3), dtype=np.uint8)
        self.m = pm.PioMatter(colorspace=pm.Colorspace.RGB888Packed, pinout=pm.Pinout.AdafruitMatrixBonnet, framebuffer=self.fb, geometry=geo)

    def show(self, rgb):
        self.fb[:] = self.np.frombuffer(rgb, dtype=self.np.uint8).reshape(self.h, self.w, 3)
        self.m.show()

    def close(self):
        self.fb[:] = 0
        self.m.show()


def fit(rgb, fw, fh, w, h):
    """Center a fw x fh frame on a w x h board (crop or pad)."""
    if (fw, fh) == (w, h):
        return rgb
    out = bytearray(w * h * 3)
    ox, oy = (w - fw) // 2, (h - fh) // 2
    for y in range(h):
        sy = y - oy
        if not 0 <= sy < fh:
            continue
        x0, x1 = max(0, ox), min(w, ox + fw)
        if x1 <= x0:
            continue
        src = (sy * fw + (x0 - ox)) * 3
        out[(y * w + x0) * 3:(y * w + x1) * 3] = rgb[src:src + (x1 - x0) * 3]
    return bytes(out)


def open_backend(a):
    names = [a.backend] if a.backend != "auto" else ["rgbmatrix", "piomatter", "term"]
    errors = []
    for n in names:
        try:
            if n == "rgbmatrix":
                return RgbMatrix(a)
            if n == "piomatter":
                return PioMatter(a)
            return Term(a.width, a.height)
        except Exception as e:  # missing module, no GPIO access, ...
            errors.append(f"{n}: {e}")
    sys.exit("dotwall-pi: no backend: " + "; ".join(errors))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0], formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__.split("\n\n", 1)[1])
    ap.add_argument("--port", type=int, default=7373)
    ap.add_argument("--bind", default="0.0.0.0")
    ap.add_argument("--backend", default="auto", choices=["auto", "rgbmatrix", "piomatter", "term"])
    ap.add_argument("--idle", type=float, default=10, help="seconds without frames before going dark")
    # hzeller options, defaults for a 2x2 P10 wall on one chain
    ap.add_argument("--rows", type=int, default=16)
    ap.add_argument("--cols", type=int, default=32)
    ap.add_argument("--chain", type=int, default=4)
    ap.add_argument("--parallel", type=int, default=1)
    ap.add_argument("--mapper", default="U-mapper")
    ap.add_argument("--brightness", type=int, default=70)
    ap.add_argument("--hardware-mapping", default="regular")
    ap.add_argument("--slowdown", type=int, default=2)
    ap.add_argument("--multiplexing", type=int, default=0)
    ap.add_argument("--row-addr-type", type=int, default=0)
    ap.add_argument("--pwm-bits", type=int, default=11)
    # piomatter / term geometry
    ap.add_argument("--width", type=int, default=64)
    ap.add_argument("--height", type=int, default=32)
    ap.add_argument("--addr-lines", type=int, default=3)
    a = ap.parse_args()

    board = open_backend(a)
    w, h = getattr(board, "w", a.width), getattr(board, "h", a.height)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((a.bind, a.port))
    print(f"dotwall-pi: {type(board).__name__} {w}x{h}, listening on {a.bind}:{a.port}", file=sys.stderr, flush=True)
    dark = bytes(w * h * 3)
    last = 0.0
    lit = False
    try:
        while True:
            r, _, _ = select.select([sock], [], [], 1.0)
            if not r:
                if lit and time.time() - last > a.idle:
                    board.show(dark)
                    lit = False
                continue
            data, _ = sock.recvfrom(65535)
            # Only the newest frame matters; drop any that queued up.
            while True:
                r, _, _ = select.select([sock], [], [], 0)
                if not r:
                    break
                data, _ = sock.recvfrom(65535)
            if len(data) < 9 or not data.startswith(MAGIC):
                continue
            fw, fh = int.from_bytes(data[5:7], "big"), int.from_bytes(data[7:9], "big")
            rgb = data[9:]
            if len(rgb) != fw * fh * 3:
                continue
            board.show(fit(rgb, fw, fh, w, h))
            last, lit = time.time(), True
    except KeyboardInterrupt:
        pass
    finally:
        board.close()


if __name__ == "__main__":
    main()
