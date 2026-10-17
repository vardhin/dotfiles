.pragma library

// Panel outlines as SVG paths, in dots (w x h).
//   circle  ellipse filling the panel     hex      flat-top hexagon
//   diamond rhombus                       strip    pill (fully rounded ends)
//   rect    plain rectangle ("" in DotSurface = no cut at all)
// Anything else is taken as a custom SVG path in a 0..100 box, scaled to w x h.
var names = ["rect", "circle", "hex", "diamond", "strip"];

function path(shape, w, h) {
    switch (shape) {
    case "":
    case "rect":
        return "";
    case "circle":
        return `M 0 ${h / 2} A ${w / 2} ${h / 2} 0 1 0 ${w} ${h / 2} A ${w / 2} ${h / 2} 0 1 0 0 ${h / 2} Z`;
    case "hex": {
        const q = w / 4;
        return `M ${q} 0 L ${w - q} 0 L ${w} ${h / 2} L ${w - q} ${h} L ${q} ${h} L 0 ${h / 2} Z`;
    }
    case "diamond":
        return `M ${w / 2} 0 L ${w} ${h / 2} L ${w / 2} ${h} L 0 ${h / 2} Z`;
    case "strip": {
        const r = Math.min(w, h) / 2;
        return `M ${r} 0 L ${w - r} 0 A ${r} ${r} 0 0 1 ${w - r} ${h} L ${r} ${h} A ${r} ${r} 0 0 1 ${r} 0 Z`;
    }
    default:
        return scale(shape, w / 100, h / 100);
    }
}

// A rectangle with rounded corners, radius r dots (the eras' panel corners).
function rounded(w, h, r) {
    r = Math.max(0, Math.min(r, Math.floor(Math.min(w, h) / 2)));
    if (r === 0)
        return "";
    return `M ${r} 0 L ${w - r} 0 Q ${w} 0 ${w} ${r} L ${w} ${h - r} Q ${w} ${h} ${w - r} ${h} L ${r} ${h} Q 0 ${h} 0 ${h - r} L 0 ${r} Q 0 0 ${r} 0 Z`;
}

// Scale every number pair in a path of absolute commands (M L C Q A Z ...).
// Arc flags are left alone by scaling only coordinate positions.
function scale(d, sx, sy) {
    const tokens = d.match(/[A-Za-z]|-?\d*\.?\d+(?:e-?\d+)?/g) || [];
    let out = [], cmd = "", n = 0;
    for (const t of tokens) {
        if (/[A-Za-z]/.test(t)) {
            cmd = t.toUpperCase();
            out.push(t);
            n = 0;
            continue;
        }
        let v = parseFloat(t);
        if (cmd === "A") {
            // rx ry rot large sweep x y
            const k = n % 7;
            if (k === 0 || k === 5) v *= sx;
            else if (k === 1 || k === 6) v *= sy;
        } else if (cmd === "H") {
            v *= sx;
        } else if (cmd === "V") {
            v *= sy;
        } else {
            v *= n % 2 === 0 ? sx : sy;
        }
        out.push(String(Math.round(v * 100) / 100));
        n++;
    }
    return out.join(" ");
}
