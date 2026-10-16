// Era scenes: what the board plays while you are away (panes/Scene.qml).
//
// Each scene draws one frame into a Canvas 2D context where 1 px = 1 dot, at
// the board's own resolution (screen / pitch). Colors are the era's tubes
// (pal.s0 .. pal.s2); alpha is the brightness: dot.frag lights a dot above
// 0.35 alpha, at full above 0.7 and at the dim level between. Nothing is
// drawn for an unlit dot (clearRect), so the era's own unlit dots show.
//
//   make(id, w, h) -> state       once per board size and era
//   draw(st, ctx, dt, pal, now)   every frame; dt in seconds, now a Date
.pragma library

const FONT = '"DepartureMono Nerd Font", "Departure Mono", monospace';

// ── Helpers ─────────────────────────────────────────────────────────
function rng(seed) {
    let s = (seed >>> 0) || 1;
    return function () {
        s ^= s << 13; s >>>= 0;
        s ^= s >> 17;
        s ^= s << 5; s >>>= 0;
        return s / 4294967296;
    };
}

function rgba(hex, a) {
    const n = parseInt(String(hex).replace("#", "").slice(0, 6), 16);
    return "rgba(" + ((n >> 16) & 255) + "," + ((n >> 8) & 255) + "," + (n & 255) + "," + a + ")";
}

function dot(ctx, x, y, c) {
    ctx.fillStyle = c;
    ctx.fillRect(Math.floor(x), Math.floor(y), 1, 1);
}

function text(ctx, s, x, y, px, c, align) {
    ctx.font = px + "px " + FONT;
    ctx.textAlign = align || "left";
    ctx.textBaseline = "top";
    ctx.fillStyle = c;
    ctx.fillText(s, Math.round(x), Math.round(y));
}

// Pixel font at `k` times its 11 px grid: one font pixel = k dots.
function bigText(ctx, s, cx, y, k, c) {
    text(ctx, s, cx, y, 11 * k, c, "center");
}

function ring(ctx, cx, cy, r, c) {
    ctx.strokeStyle = c;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.stroke();
}

function line(ctx, x0, y0, x1, y1, c) {
    ctx.strokeStyle = c;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(x0 + 0.5, y0 + 0.5);
    ctx.lineTo(x1 + 0.5, y1 + 0.5);
    ctx.stroke();
}

function pad(n) {
    return (n < 10 ? "0" : "") + n;
}

// ── Scenes ──────────────────────────────────────────────────────────
const LINES = [
    "READY.", "10 PRINT \"HELLO WORLD\"", "20 GOTO 10", "RUN", "LOAD \"*\",8,1", "SEARCHING FOR *",
    "LOADING", "MEM CHECK 640K OK", "> CONNECT 9600", "CARRIER LOST", "C:\\> DIR /W", "DOTSHELL.EXE",
    "PING 10.0.0.1 ... 3 MS", "BOOT SECTOR OK", "PHOSPHOR WARM", "SCANLINE 262", "> _"
];

const scenes = {
    // Amber CRT: a terminal typing to itself.
    phosphor: {
        make(st) {
            st.lines = [];
            st.cur = "";
            st.target = LINES[0];
            st.i = 0;
            st.acc = 0;
        },
        draw(st, ctx, dt, p) {
            const lh = 13, x0 = 4;
            st.acc += dt;
            while (st.acc > 0.06) {
                st.acc -= 0.06;
                if (st.cur.length < st.target.length) {
                    st.cur += st.target[st.cur.length];
                } else if (st.r() < 0.06) {
                    st.lines.push(st.cur);
                    st.cur = "";
                    st.i = (st.i + 1) % LINES.length;
                    st.target = LINES[st.i];
                }
            }
            const max = Math.max(1, Math.floor((st.h - 8) / lh) - 1);
            while (st.lines.length > max)
                st.lines.shift();
            st.lines.forEach((l, i) => text(ctx, l, x0, 4 + i * lh, 11, rgba(p.s0, i === st.lines.length - 1 ? 1 : 0.6)));
            const y = 4 + st.lines.length * lh;
            text(ctx, st.cur, x0, y, 11, rgba(p.s1, 1));
            if (Math.floor(st.t * 2) % 2 === 0) {
                ctx.fillStyle = rgba(p.s0, 1);
                ctx.fillRect(x0 + st.cur.length * 7, y + 1, 6, 10);
            }
        }
    },

    // Tokyo Night: a skyline in the rain under a flickering neon sign.
    tokyo: {
        make(st) {
            st.buildings = [];
            let x = 0;
            while (x < st.w) {
                const bw = 8 + Math.floor(st.r() * 22);
                const bh = Math.floor(st.h * (0.18 + st.r() * 0.45));
                const win = [];
                for (let yy = st.h - bh + 3; yy < st.h - 2; yy += 3)
                    for (let xx = x + 2; xx < x + bw - 2; xx += 3)
                        if (st.r() < 0.35) win.push([xx, yy, st.r()]);
                st.buildings.push({ x: x, w: bw, h: bh, win: win });
                x += bw + 1;
            }
            st.drops = [];
            for (let i = 0; i < st.w * st.h / 90; i++)
                st.drops.push([st.r() * st.w, st.r() * st.h, 0.6 + st.r() * 0.8]);
        },
        draw(st, ctx, dt, p) {
            for (const b of st.buildings) {
                // Roof and walls in the dim tube; a spire on the tall ones.
                ctx.fillStyle = rgba(p.s2, 0.5);
                ctx.fillRect(b.x, st.h - b.h, b.w, 1);
                ctx.fillRect(b.x, st.h - b.h, 1, b.h);
                ctx.fillRect(b.x + b.w - 1, st.h - b.h, 1, b.h);
                if (b.h > st.h * 0.5)
                    ctx.fillRect(b.x + Math.floor(b.w / 2), st.h - b.h - 6, 1, 6);
                for (const w of b.win)
                    if (Math.sin(st.t * 0.3 + w[2] * 40) > -0.6)
                        dot(ctx, w[0], w[1], rgba(w[2] < 0.5 ? p.s1 : p.s2, w[2] < 0.15 ? 1 : 0.5));
            }
            const fall = 60 * dt;
            for (const d of st.drops) {
                d[1] += fall * d[2];
                d[0] -= fall * d[2] * 0.3;
                if (d[1] > st.h) { d[1] -= st.h; d[0] = st.r() * st.w * 1.2; }
                if (d[0] < 0) d[0] += st.w;
                dot(ctx, d[0], d[1], rgba(p.s1, 0.5));
                dot(ctx, d[0] + 0.3, d[1] - 1, rgba(p.s1, 0.4));
            }
            const flick = st.r() < 0.04 ? 0.4 : 1;
            const k = Math.max(1, Math.floor(st.w / 90));
            bigText(ctx, "RAIN CITY", st.w / 2, Math.floor(st.h * 0.12), k, rgba(p.s0, flick));
            bigText(ctx, "24H  NOODLE  BAR", st.w / 2, Math.floor(st.h * 0.12) + 13 * k + 2, Math.max(1, k - 1), rgba(p.s1, 0.6));
        }
    },

    // 90s Nights: the sun sets over a neon grid that never ends.
    nineties: {
        make(st) {},
        draw(st, ctx, dt, p) {
            const hz = Math.floor(st.h * 0.58), cx = st.w / 2, r = Math.floor(st.h * 0.3);
            for (let y = hz - r; y < hz; y++) {
                const band = (hz - y) / r;
                const gap = (y + Math.floor(st.t * 6)) % 7 < 7 * (1 - band) * 0.5;
                if (gap) continue;
                const half = Math.sqrt(Math.max(0, r * r - (y - hz) * (y - hz)));
                ctx.fillStyle = rgba(band > 0.5 ? p.s2 : p.s0, 1);
                ctx.fillRect(Math.floor(cx - half), y, Math.ceil(half * 2), 1);
            }
            const c = rgba(p.s1, 1), dim = rgba(p.s1, 0.5);
            line(ctx, 0, hz, st.w, hz, c);
            const off = (st.t * 0.6) % 1;
            for (let i = 0; i < 12; i++) {
                const z = i + 1 - off;
                const y = hz + (st.h - hz) / (z * 0.55);
                if (y < st.h) line(ctx, 0, Math.floor(y), st.w, Math.floor(y), i < 3 ? c : dim);
            }
            for (let i = -12; i <= 12; i++)
                line(ctx, cx + i * 4, hz, cx + i * st.w / 6, st.h, dim);
            if (Math.floor(st.t * 1.3) % 6 !== 0)
                text(ctx, "OPEN 24 HRS", st.w - 4, 4, 11, rgba(p.s0, 1), "right");
        }
    },

    // Matrix: green rain, glyph columns falling at their own speed.
    matrix: {
        make(st) {
            st.cw = 7; st.ch = 11;
            st.cols = [];
            for (let i = 0; i < Math.floor(st.w / st.cw); i++)
                st.cols.push({ y: -st.r() * st.h, v: 6 + st.r() * 14, len: 6 + Math.floor(st.r() * 18), g: [] });
            st.glyphs = "ｱｲｳｴｵｶｷｸｹｺ01234567890ABCDEFZ:.=*+<>";
        },
        draw(st, ctx, dt, p) {
            for (let i = 0; i < st.cols.length; i++) {
                const c = st.cols[i];
                c.y += c.v * dt * st.ch / 2;
                const head = Math.floor(c.y / st.ch);
                if ((head - c.len) * st.ch > st.h) {
                    c.y = -st.r() * st.h * 0.5;
                    c.v = 6 + st.r() * 14;
                }
                for (let k = 0; k < c.len; k++) {
                    const row = head - k;
                    if (row < 0 || row * st.ch > st.h) continue;
                    if (!c.g[row] || st.r() < 0.02) c.g[row] = st.glyphs[Math.floor(st.r() * st.glyphs.length)];
                    const a = k === 0 ? 1 : k < c.len / 2 ? 0.75 : 0.5;
                    text(ctx, c.g[row], i * st.cw, row * st.ch, 11, rgba(k === 0 ? p.s1 : p.s0, a));
                }
            }
        }
    },

    // VFD: a car stereo, clock and spectrum.
    vfd: {
        make(st) {
            st.bands = [];
            for (let i = 0; i < 24; i++) st.bands.push({ v: 0, peak: 0, ph: st.r() * 6 });
        },
        draw(st, ctx, dt, p, now) {
            const k = Math.max(2, Math.floor(st.h / 40));
            bigText(ctx, pad(now.getHours()) + (now.getSeconds() % 2 ? ":" : " ") + pad(now.getMinutes()), st.w / 2, Math.floor(st.h * 0.08), k, rgba(p.s0, 1));
            text(ctx, "FM  98.3  ST", st.w / 2, Math.floor(st.h * 0.08) + 13 * k, 11, rgba(p.s1, 1), "center");
            const n = st.bands.length, bw = Math.max(2, Math.floor(st.w * 0.7 / n) - 1);
            const x0 = Math.floor((st.w - n * (bw + 1)) / 2), base = st.h - 4, hmax = Math.floor(st.h * 0.4);
            for (let i = 0; i < n; i++) {
                const b = st.bands[i];
                const target = 0.25 + 0.6 * Math.abs(Math.sin(st.t * (1.3 + i * 0.17) + b.ph)) * (1 - i / n * 0.6) + st.r() * 0.15;
                b.v += (target - b.v) * Math.min(1, dt * 10);
                b.peak = Math.max(b.v, b.peak - dt * 0.35);
                const hh = Math.floor(b.v * hmax);
                for (let y = 0; y < hh; y += 2) {
                    ctx.fillStyle = rgba(y > hmax * 0.75 ? p.s1 : p.s0, 1);
                    ctx.fillRect(x0 + i * (bw + 1), base - y, bw, 1);
                }
                ctx.fillStyle = rgba(p.s1, 1);
                ctx.fillRect(x0 + i * (bw + 1), base - Math.floor(b.peak * hmax), bw, 1);
            }
        }
    },

    // Frutiger Aero: bubbles rising through sky glass.
    aero: {
        make(st) {
            st.b = [];
            for (let i = 0; i < 22; i++) st.b.push(scenes.aero.bubble(st, true));
        },
        bubble(st, any) {
            return { x: st.r() * st.w, y: any ? st.r() * st.h : st.h + 20, r: 3 + st.r() * Math.min(18, st.h / 8), v: 6 + st.r() * 10, ph: st.r() * 6 };
        },
        draw(st, ctx, dt, p) {
            for (let i = 0; i < st.b.length; i++) {
                const b = st.b[i];
                b.y -= b.v * dt;
                b.x += Math.sin(st.t * 0.8 + b.ph) * dt * 4;
                if (b.y + b.r < 0) st.b[i] = scenes.aero.bubble(st, false);
                ring(ctx, b.x, b.y, b.r, rgba(i % 3 === 0 ? p.s2 : p.s0, 0.9));
                dot(ctx, b.x - b.r * 0.45, b.y - b.r * 0.45, rgba(p.s1, 1));
            }
        }
    },

    // Game Boy: Conway's Life on 2x2 cells, reseeded when it settles.
    gameboy: {
        make(st) {
            st.cs = 2;
            st.gw = Math.floor(st.w / st.cs);
            st.gh = Math.floor(st.h / st.cs);
            scenes.gameboy.seed(st);
        },
        seed(st) {
            st.g = new Uint8Array(st.gw * st.gh);
            for (let i = 0; i < st.g.length; i++) st.g[i] = st.r() < 0.28 ? 1 : 0;
            st.acc = 0;
            st.gen = 0;
            st.last = -1;
        },
        draw(st, ctx, dt, p) {
            st.acc += dt;
            if (st.acc > 0.12) {
                st.acc = 0;
                const n = new Uint8Array(st.g.length);
                let alive = 0;
                for (let y = 0; y < st.gh; y++)
                    for (let x = 0; x < st.gw; x++) {
                        let c = 0;
                        for (let dy = -1; dy <= 1; dy++)
                            for (let dx = -1; dx <= 1; dx++)
                                if (dx || dy) c += st.g[((y + dy + st.gh) % st.gh) * st.gw + (x + dx + st.gw) % st.gw];
                        const i = y * st.gw + x;
                        n[i] = (c === 3 || (c === 2 && st.g[i])) ? 1 : 0;
                        alive += n[i];
                    }
                st.g = n;
                st.gen++;
                if (alive === st.last && st.gen > 40 || st.gen > 900) scenes.gameboy.seed(st);
                st.last = alive;
            }
            ctx.fillStyle = rgba(p.s0, 1);
            for (let y = 0; y < st.gh; y++)
                for (let x = 0; x < st.gw; x++)
                    if (st.g[y * st.gw + x]) ctx.fillRect(x * st.cs, y * st.cs, st.cs, st.cs);
        }
    },

    // Nixie: tubes glowing the time; the other numerals sit dim behind.
    nixie: {
        make(st) {},
        draw(st, ctx, dt, p, now) {
            // Six tubes and two colons when they fit, else hours and minutes.
            const n = st.w >= 80 ? 6 : 4;
            const k = Math.max(1, Math.min(Math.floor(st.h / 22), Math.floor(st.w / (n === 6 ? 80 : 54))));
            const digits = (pad(now.getHours()) + pad(now.getMinutes()) + pad(now.getSeconds())).slice(0, n);
            const cell = 8 * k, gap = 4 * k;
            const total = n * (cell + gap) - gap + (n / 2 - 1) * (3 * k);
            let x = Math.floor((st.w - total) / 2) + cell / 2;
            const y = Math.floor((st.h - 13 * k) / 2);
            for (let i = 0; i < n; i++) {
                ring(ctx, x, y + 6.5 * k, 5.5 * k, rgba(p.s2, 0.4));
                // The unlit numerals stacked in the tube, read as one dim 8.
                bigText(ctx, "8", x, y, k, rgba(p.s2, 0.45));
                bigText(ctx, digits[i], x, y, k, rgba(p.s0, 1));
                x += cell + gap;
                if (i % 2 === 1 && i < n - 1) {
                    const on = now.getMilliseconds() < 500;
                    ctx.fillStyle = rgba(p.s1, on ? 1 : 0.45);
                    ctx.fillRect(x - gap - k, y + 4 * k, k, k);
                    ctx.fillRect(x - gap - k, y + 9 * k, k, k);
                    x += 3 * k;
                }
            }
        }
    },

    // Split-flap: a departure board flipping to its next rows.
    flap: {
        make(st) {
            st.dest = ["KYOTO", "MADRAS", "BERLIN", "OSAKA", "CHENNAI", "LISBON", "VELLORE", "HELSINKI", "SEOUL", "QUITO", "OSLO", "DUBAI"];
            st.rows = [];
            st.acc = 0;
            const n = Math.max(3, Math.floor((st.h - 30) / 16));
            for (let i = 0; i < n; i++) st.rows.push(scenes.flap.row(st, i));
        },
        row(st, i) {
            const d = st.dest[Math.floor(st.r() * st.dest.length)];
            const hh = pad(6 + Math.floor(st.r() * 17)), mm = pad(Math.floor(st.r() * 12) * 5);
            const target = (hh + mm + " " + d + "            ").slice(0, 16) + (st.r() < 0.2 ? "DELAYED" : "ON TIME");
            return { shown: " ".repeat(target.length), target: target };
        },
        draw(st, ctx, dt, p) {
            const A = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
            st.acc += dt;
            if (st.acc > 9) {
                st.acc = 0;
                st.rows.shift();
                st.rows.push(scenes.flap.row(st, 0));
            }
            text(ctx, "DEPARTURES", 4, 4, 11, rgba(p.s1, 1));
            st.rows.forEach((r, i) => {
                let s = "";
                for (let c = 0; c < r.target.length; c++) {
                    const want = r.target[c], have = r.shown[c];
                    if (have === want || st.r() < 0.5) s += have;
                    else s += A[(A.indexOf(have) + 1) % A.length] ?? want;
                }
                r.shown = s;
                const y = 22 + i * 16;
                ctx.fillStyle = rgba(p.s2, 0.45);
                ctx.fillRect(2, y + 6, st.w - 4, 1);
                text(ctx, s, 4, y, 11, rgba(s.includes("DELAYED") ? p.s2 : p.s0, 1));
            });
        }
    },

    // Night vision: a radar sweep with fading returns.
    nightvision: {
        make(st) {
            st.blips = [];
        },
        draw(st, ctx, dt, p) {
            const cx = st.w / 2, cy = st.h / 2, R = Math.min(st.w, st.h) * 0.45;
            for (let i = 1; i <= 4; i++) ring(ctx, cx, cy, R * i / 4, rgba(p.s2, 0.45));
            line(ctx, cx - R, cy, cx + R, cy, rgba(p.s2, 0.45));
            line(ctx, cx, cy - R, cx, cy + R, rgba(p.s2, 0.45));
            const a = st.t * 1.4;
            for (let k = 0; k < 14; k++) {
                const b = a - k * 0.04;
                line(ctx, cx, cy, cx + Math.cos(b) * R, cy + Math.sin(b) * R, rgba(p.s0, k === 0 ? 1 : 0.5));
            }
            if (st.r() < dt * 1.5) {
                const d = R * (0.2 + st.r() * 0.75);
                st.blips.push({ x: cx + Math.cos(a) * d, y: cy + Math.sin(a) * d, life: 1 });
            }
            st.blips = st.blips.filter(b => (b.life -= dt * 0.3) > 0);
            for (const b of st.blips) {
                ctx.fillStyle = rgba(p.s1, b.life > 0.5 ? 1 : 0.5);
                ctx.fillRect(Math.floor(b.x) - 1, Math.floor(b.y) - 1, 2, 2);
            }
            text(ctx, "GEN III  x4", 4, 4, 11, rgba(p.s0, 1));
        }
    },

    // Vaporwave: a wireframe pyramid turning over the grid at dusk.
    vapor: {
        make(st) {},
        draw(st, ctx, dt, p) {
            scenes.nineties.draw(st, ctx, dt * 0.4, p);
            const cx = st.w / 2, cy = st.h * 0.36, s = st.h * 0.16, a = st.t * 0.5;
            const pts = [[0, -1.2, 0], [-1, 0.6, -1], [1, 0.6, -1], [1, 0.6, 1], [-1, 0.6, 1]].map(v => {
                const x = v[0] * Math.cos(a) - v[2] * Math.sin(a), z = v[0] * Math.sin(a) + v[2] * Math.cos(a);
                const k = 3 / (3 + z);
                return [cx + x * s * k, cy + v[1] * s * k];
            });
            const e = [[0, 1], [0, 2], [0, 3], [0, 4], [1, 2], [2, 3], [3, 4], [4, 1]];
            for (const [i, j] of e) line(ctx, pts[i][0], pts[i][1], pts[j][0], pts[j][1], rgba(p.s2, 1));
        }
    },

    // Arcade: invaders marching down, a ship answering.
    arcade: {
        SPRITE: ["00100000100", "00010001000", "00111111100", "01101110110", "11111111111", "10111111101", "10100000101", "00011011000"],
        make(st) {
            st.ox = 4; st.dir = 1; st.oy = 4; st.acc = 0; st.frame = 0;
            // As many invaders as the board holds (10 x 4 on a screen, fewer on a wall).
            st.icols = Math.max(2, Math.min(10, Math.floor((st.w - 8) / 14)));
            st.irows = Math.max(1, Math.min(4, Math.floor((st.h - 20) / 11)));
            st.alive = [];
            for (let i = 0; i < st.icols * st.irows; i++) st.alive.push(true);
            st.shot = null;
            st.ship = st.w / 2;
        },
        draw(st, ctx, dt, p) {
            const S = scenes.arcade.SPRITE, cols = st.icols, rows = st.irows, gx = 14, gy = 11;
            st.acc += dt;
            if (st.acc > 0.35) {
                st.acc = 0;
                st.frame ^= 1;
                st.ox += st.dir * 2;
                if (st.ox < 2 || st.ox + cols * gx > st.w - 2) { st.dir = -st.dir; st.oy += 4; }
                if (st.oy + rows * gy > st.h - 16 || st.alive.every(v => !v)) scenes.arcade.make(st);
            }
            for (let r = 0; r < rows; r++)
                for (let c = 0; c < cols; c++) {
                    if (!st.alive[r * cols + c]) continue;
                    const x0 = st.ox + c * gx, y0 = st.oy + r * gy;
                    ctx.fillStyle = rgba(r === 0 ? p.s2 : r < 2 ? p.s1 : p.s0, 1);
                    for (let y = 0; y < S.length; y++)
                        for (let x = 0; x < S[y].length; x++) {
                            const on = S[y][x] === "1" && !(st.frame && y === 7 && (x < 3 || x > 7));
                            if (on) ctx.fillRect(x0 + x, y0 + y, 1, 1);
                        }
                }
            st.ship += Math.sin(st.t * 0.9) * dt * 30;
            ctx.fillStyle = rgba(p.s0, 1);
            ctx.fillRect(Math.floor(st.ship) - 5, st.h - 5, 11, 3);
            ctx.fillRect(Math.floor(st.ship) - 1, st.h - 7, 3, 2);
            if (!st.shot && st.r() < dt * 2) st.shot = { x: Math.floor(st.ship), y: st.h - 8 };
            if (st.shot) {
                st.shot.y -= dt * 90;
                ctx.fillRect(st.shot.x, Math.floor(st.shot.y), 1, 3);
                const c = Math.floor((st.shot.x - st.ox) / gx), r = Math.floor((st.shot.y - st.oy) / gy);
                if (c >= 0 && c < cols && r >= 0 && r < rows && st.alive[r * cols + c]) { st.alive[r * cols + c] = false; st.shot = null; }
                else if (st.shot.y < 0) st.shot = null;
            }
        }
    },

    // Blueprint: a drafting pen tracing a spirograph on the grid.
    blueprint: {
        make(st) {
            st.k = 0;
            st.R = 5 + Math.floor(st.r() * 4); st.q = 2 + Math.floor(st.r() * 3); st.d = 0.6 + st.r() * 0.6;
            st.path = [];
        },
        draw(st, ctx, dt, p) {
            for (let x = 0; x < st.w; x += 12) line(ctx, x, 0, x, st.h, rgba(p.s2, 0.45));
            for (let y = 0; y < st.h; y += 12) line(ctx, 0, y, st.w, y, rgba(p.s2, 0.45));
            const cx = st.w / 2, cy = st.h / 2, sc = Math.min(st.w, st.h) * 0.42 / (st.R - st.q + st.d * st.q);
            const steps = Math.floor(dt * 240);
            for (let i = 0; i < steps; i++) {
                st.k += 0.01;
                const R = st.R, q = st.q, d = st.d * q;
                st.path.push([cx + sc * ((R - q) * Math.cos(st.k) + d * Math.cos((R - q) / q * st.k)), cy + sc * ((R - q) * Math.sin(st.k) - d * Math.sin((R - q) / q * st.k))]);
            }
            if (st.path.length > 6000) scenes.blueprint.make(st);
            ctx.strokeStyle = rgba(p.s0, 1);
            ctx.lineWidth = 1;
            ctx.beginPath();
            st.path.forEach((pt, i) => i ? ctx.lineTo(pt[0], pt[1]) : ctx.moveTo(pt[0], pt[1]));
            ctx.stroke();
            const last = st.path[st.path.length - 1];
            if (last) ring(ctx, last[0], last[1], 2, rgba(p.s1, 1));
            text(ctx, "SHEET 1 OF 1   SCALE 1:1", st.w - 4, st.h - 14, 11, rgba(p.s1, 1), "right");
        }
    }
};

const names = {
    phosphor: "TERMINAL", tokyo: "RAIN CITY", nineties: "SUNSET GRID", matrix: "DIGITAL RAIN",
    vfd: "CAR STEREO", aero: "BUBBLES", gameboy: "LIFE", nixie: "NIXIE CLOCK", flap: "DEPARTURES",
    nightvision: "RADAR", vapor: "VAPOR", arcade: "INVADERS", blueprint: "DRAFTING"
};

function has(id) {
    return !!scenes[id];
}

function title(id) {
    return names[id] ?? "TERMINAL";
}

function make(id, w, h) {
    const sc = scenes[id] ? id : "phosphor";
    const st = { id: sc, w: Math.max(1, Math.floor(w)), h: Math.max(1, Math.floor(h)), t: 0, r: rng(0x9e3779b9 ^ (w * 31 + h)) };
    scenes[sc].make(st);
    return st;
}

function draw(st, ctx, dt, pal, now) {
    st.t += dt;
    ctx.clearRect(0, 0, st.w, st.h);
    scenes[st.id].draw(st, ctx, Math.min(dt, 0.1), pal, now || new Date());
}
