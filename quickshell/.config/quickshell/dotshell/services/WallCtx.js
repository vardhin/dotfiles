// A software Canvas 2D for the P10 wall (services/Wall.qml): the subset of
// the API panes/Scenes.js draws with, into a plain RGB buffer, so era scenes,
// clocks and text can be rendered at the wall's own size (64 x 32) without a
// window, a GPU or a grab.
//
//   const c = WallCtx.make(64, 32);
//   Scenes.draw(state, c, dt, pal, now);
//   const rgb = WallCtx.frame(c, unlit);     // Uint8Array w*h*3
//
// Like dot.frag, alpha is brightness: under 0.35 a dot stays off, under 0.7
// it is lit at 70 %, else full. Text uses a 5x7 LED font (Scenes' 11 px
// pixel font maps onto it at 1x; 22 px at 2x).
.pragma library

// 5x7 glyphs, one byte per row, bit 4 = leftmost column.
const FONT = {
    " ": [0, 0, 0, 0, 0, 0, 0], "!": [4, 4, 4, 4, 4, 0, 4], "\"": [10, 10, 0, 0, 0, 0, 0], "#": [10, 31, 10, 10, 10, 31, 10],
    "$": [4, 15, 20, 14, 5, 30, 4], "%": [25, 25, 2, 4, 8, 19, 19], "&": [12, 18, 20, 8, 21, 18, 13], "'": [4, 4, 0, 0, 0, 0, 0],
    "(": [2, 4, 8, 8, 8, 4, 2], ")": [8, 4, 2, 2, 2, 4, 8], "*": [0, 4, 21, 14, 21, 4, 0], "+": [0, 4, 4, 31, 4, 4, 0],
    ",": [0, 0, 0, 0, 12, 4, 8], "-": [0, 0, 0, 31, 0, 0, 0], ".": [0, 0, 0, 0, 0, 12, 12], "/": [1, 1, 2, 4, 8, 16, 16],
    "0": [14, 17, 19, 21, 25, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14], "2": [14, 17, 1, 2, 4, 8, 31], "3": [31, 2, 4, 2, 1, 17, 14],
    "4": [2, 6, 10, 18, 31, 2, 2], "5": [31, 16, 30, 1, 1, 17, 14], "6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8],
    "8": [14, 17, 17, 14, 17, 17, 14], "9": [14, 17, 17, 15, 1, 2, 12], ":": [0, 12, 12, 0, 12, 12, 0], ";": [0, 12, 12, 0, 12, 4, 8],
    "<": [2, 4, 8, 16, 8, 4, 2], "=": [0, 0, 31, 0, 31, 0, 0], ">": [8, 4, 2, 1, 2, 4, 8], "?": [14, 17, 1, 2, 4, 0, 4],
    "@": [14, 17, 1, 13, 21, 21, 14], "A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14],
    "D": [28, 18, 17, 17, 17, 18, 28], "E": [31, 16, 16, 30, 16, 16, 31], "F": [31, 16, 16, 30, 16, 16, 16], "G": [14, 17, 16, 23, 17, 17, 15],
    "H": [17, 17, 17, 31, 17, 17, 17], "I": [14, 4, 4, 4, 4, 4, 14], "J": [7, 2, 2, 2, 2, 18, 12], "K": [17, 18, 20, 24, 20, 18, 17],
    "L": [16, 16, 16, 16, 16, 16, 31], "M": [17, 27, 21, 21, 17, 17, 17], "N": [17, 17, 25, 21, 19, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14],
    "P": [30, 17, 17, 30, 16, 16, 16], "Q": [14, 17, 17, 17, 21, 18, 13], "R": [30, 17, 17, 30, 20, 18, 17], "S": [15, 16, 16, 14, 1, 1, 30],
    "T": [31, 4, 4, 4, 4, 4, 4], "U": [17, 17, 17, 17, 17, 17, 14], "V": [17, 17, 17, 17, 17, 10, 4], "W": [17, 17, 17, 21, 21, 21, 10],
    "X": [17, 17, 10, 4, 10, 17, 17], "Y": [17, 17, 17, 10, 4, 4, 4], "Z": [31, 1, 2, 4, 8, 16, 31], "[": [14, 8, 8, 8, 8, 8, 14],
    "\\": [16, 16, 8, 4, 2, 1, 1], "]": [14, 2, 2, 2, 2, 2, 14], "^": [4, 10, 17, 0, 0, 0, 0], "_": [0, 0, 0, 0, 0, 0, 31],
    "|": [4, 4, 4, 4, 4, 4, 4], "~": [0, 0, 8, 21, 2, 0, 0], "♪": [6, 5, 4, 4, 12, 28, 24], "·": [0, 0, 0, 4, 0, 0, 0]
};

function glyph(ch) {
    const g = FONT[ch] ?? FONT[ch.toUpperCase()];
    if (g)
        return g;
    // Anything else (kana in the Matrix rain, symbols): a stable pattern of
    // its own, so the rain still reads as glyphs.
    let h = ch.codePointAt(0) * 2654435761 >>> 0;
    const rows = [];
    for (let i = 0; i < 7; i++) {
        h ^= h << 13; h >>>= 0; h ^= h >> 17; h ^= h << 5; h >>>= 0;
        rows.push((h >> 3) & 31);
    }
    return rows;
}

function parse(c) {
    if (typeof c !== "string")
        return [255, 255, 255, 1];
    let m = c.match(/rgba?\(([^)]+)\)/);
    if (m) {
        const p = m[1].split(",").map(Number);
        return [p[0], p[1], p[2], p.length > 3 ? p[3] : 1];
    }
    m = c.match(/^#([0-9a-f]{6,8})$/i);
    if (m) {
        const n = parseInt(m[1].slice(-6), 16);
        return [(n >> 16) & 255, (n >> 8) & 255, n & 255, 1];
    }
    return [255, 255, 255, 1];
}

function make(w, h) {
    const c = {
        w: w, h: h,
        rgb: new Float32Array(w * h * 3),
        a: new Float32Array(w * h),
        fillStyle: "#ffffff", strokeStyle: "#ffffff", lineWidth: 1,
        font: "11px mono", textAlign: "left", textBaseline: "top",
        path: [], start: null
    };
    c.clearRect = (x, y, ww, hh) => {
        for (let yy = Math.max(0, Math.floor(y)); yy < Math.min(h, y + hh); yy++)
            for (let xx = Math.max(0, Math.floor(x)); xx < Math.min(w, x + ww); xx++) {
                const i = yy * w + xx;
                c.a[i] = 0;
                c.rgb[i * 3] = c.rgb[i * 3 + 1] = c.rgb[i * 3 + 2] = 0;
            }
    };
    c.plot = (x, y, col) => {
        x = Math.floor(x); y = Math.floor(y);
        if (x < 0 || y < 0 || x >= w || y >= h)
            return;
        const i = y * w + x;
        // Brighter wins, like a lit LED over a dim one.
        if (col[3] >= c.a[i]) {
            c.a[i] = col[3];
            c.rgb[i * 3] = col[0]; c.rgb[i * 3 + 1] = col[1]; c.rgb[i * 3 + 2] = col[2];
        }
    };
    c.fillRect = (x, y, ww, hh) => {
        const col = parse(c.fillStyle);
        const x0 = Math.floor(x), y0 = Math.floor(y), x1 = Math.ceil(x + ww), y1 = Math.ceil(y + hh);
        for (let yy = Math.max(0, y0); yy < Math.min(h, y1); yy++)
            for (let xx = Math.max(0, x0); xx < Math.min(w, x1); xx++)
                c.plot(xx, yy, col);
    };
    c.fillText = (s, x, y) => {
        const px = parseInt(String(c.font)) || 11;
        const k = Math.max(1, Math.round(px / 11));
        const adv = 6 * k;
        const width = String(s).length * adv - k;
        let x0 = c.textAlign === "center" ? x - width / 2 : c.textAlign === "right" ? x - width : x;
        // Scenes lay text out on 11 px lines with 7 px capitals 2 px down.
        const y0 = Math.round(y) + 2 * k;
        const col = parse(c.fillStyle);
        for (const ch of String(s)) {
            const g = glyph(ch);
            for (let r = 0; r < 7; r++)
                for (let b = 0; b < 5; b++)
                    if (g[r] & (16 >> b))
                        for (let dy = 0; dy < k; dy++)
                            for (let dx = 0; dx < k; dx++)
                                c.plot(Math.round(x0) + b * k + dx, y0 + r * k + dy, col);
            x0 += adv;
        }
    };
    c.beginPath = () => { c.path = []; };
    c.moveTo = (x, y) => { c.path.push(["m", x, y]); };
    c.lineTo = (x, y) => { c.path.push(["l", x, y]); };
    c.arc = (cx, cy, r, a0, a1) => {
        const n = Math.max(8, Math.ceil(r * 6));
        for (let i = 0; i <= n; i++) {
            const t = a0 + (a1 - a0) * i / n;
            c.path.push([i ? "l" : "m", cx + Math.cos(t) * r, cy + Math.sin(t) * r]);
        }
    };
    c.stroke = () => {
        const col = parse(c.strokeStyle);
        let px = 0, py = 0;
        for (const [op, x, y] of c.path) {
            if (op === "l") {
                const steps = Math.max(1, Math.ceil(Math.max(Math.abs(x - px), Math.abs(y - py))));
                for (let i = 0; i <= steps; i++)
                    c.plot(px + (x - px) * i / steps, py + (y - py) * i / steps, col);
            }
            px = x; py = y;
        }
    };
    c.getContext = () => c;
    return c;
}

// The frame as LEDs: 8-bit RGB, w*h*3. Dots under 0.35 alpha are off (or the
// era's unlit color, very dim, when given), 0.35 .. 0.7 at 70 %, else full.
function frame(c, unlit) {
    const out = new Uint8Array(c.w * c.h * 3);
    const u = unlit ? parse(unlit) : [0, 0, 0, 1];
    for (let i = 0; i < c.w * c.h; i++) {
        const a = c.a[i];
        const k = a < 0.35 ? 0 : a < 0.7 ? 0.7 : 1;
        for (let j = 0; j < 3; j++)
            out[i * 3 + j] = k ? Math.round(c.rgb[i * 3 + j] * k) : Math.round(u[j] * 0.12);
    }
    return out;
}

const B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
function base64(bytes) {
    let s = "";
    for (let i = 0; i < bytes.length; i += 3) {
        const n = (bytes[i] << 16) | ((bytes[i + 1] ?? 0) << 8) | (bytes[i + 2] ?? 0);
        s += B64[(n >> 18) & 63] + B64[(n >> 12) & 63] + (i + 1 < bytes.length ? B64[(n >> 6) & 63] : "=") + (i + 2 < bytes.length ? B64[n & 63] : "=");
    }
    return s;
}
