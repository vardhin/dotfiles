.pragma library
.import "Palettes.js" as Palettes

// How a notification looks in the eras whose panels are finished, from the
// design canvas's Messages boards (dot-shell-panels.html): the card's fill
// and rule (the live one ruled in the accent), the app name, the summary,
// the body, the time, the action keys, and the pane's heading. Used by the
// popups (ToastStack.qml) and the message centre (MessagesPane.qml) through
// NotifCard.qml. Other eras: null, the plain dot layout.
const looks = {
    // White glass cards on the sky, an app marble, navy words.
    aero: {
        fill: "#ffffff", rim: "#cdeaf8", live: "#62c3ee", radius: 3,
        app: "#1f7fd1", text: "#0b3f80", body: "#1f7fd1", time: "#62a8d0", crit: "#c8323c",
        keyFill: "#e8f6fd", keyRim: "#9fd8f5", keyInk: "#0b3f80",
        head: "#0b3f80", sub: "#1f7fd1", marble: true
    },
    // Pale blue ruled notes on the drafting paper, the live one ruled in
    // white; pale blue app names, near-white words, boxed white keys.
    blueprint: {
        fill: "transparent", rim: "#a9cdfa", live: "#ffffff", radius: 0,
        app: "#a9cdfa", text: "#e8f1ff", body: "#a9cdfa", time: "#a9cdfa", crit: "#ff9b8a",
        keyFill: "transparent", keyRim: "#e8f1ff", keyInk: "#ffffff",
        head: "#ffffff", sub: "#a9cdfa", marble: false
    },
    // Messages on the inbox's white sheet: violet-ruled cards, the live one
    // ruled hot pink; pink app names, near-black words, lilac push keys.
    vapor: {
        fill: "transparent", rim: "#b967ff", live: "#ff71ce", radius: 0,
        app: "#ff71ce", text: "#130a24", body: "#3d1d63", time: "#b967ff", crit: "#ff3d7f",
        keyFill: "#c9b8e8", keyRim: "#3d1d63", keyInk: "#130a24",
        head: "#130a24", sub: "#ff71ce", marble: false
    },
    // Split-Flap: the arrivals board's cards, flap dark ruled in the rim's
    // grey, the live one in yellow; yellow app names, off-white words,
    // grey times, yellow tags with dark words.
    flap: {
        fill: "#212121", rim: "#2a2a2a", live: "#ffd400", radius: 0,
        app: "#ffd400", text: "#f2f2e6", body: "#bdbdb0", time: "#6e6e64", crit: "#ff5a36",
        keyFill: "#ffd400", keyRim: "#ffd400", keyInk: "#141414",
        head: "#ffd400", sub: "#ffd400", marble: false
    },
    // Nixie: ivory cards on the walnut, ruled in the paper's tan, the live
    // one in cathode orange; dark brown words, brass app names and times,
    // polished brass keys with dark words, the heading glowing.
    nixie: {
        fill: "#efe2c4", rim: "#d8c49a", live: "#ff7a1a", radius: 0,
        app: "#8a5a1e", text: "#3a1d0e", body: "#5a2e16", time: "#8a5a1e", crit: "#c2410c",
        keyFill: "#d9a95a", keyRim: "#8a5a1e", keyInk: "#3a1d0e",
        head: "#ffc285", sub: "#ff7a1a", marble: false
    },
    // 90s Nights: deep violet-ruled cards on the dot glass, the live one
    // ruled hot pink; electric blue app names, yellow words, pink bodies,
    // yellow keys with dark words.
    nineties: {
        fill: "transparent", rim: "#3b0d5c", live: "#ff2e97", radius: 0,
        app: "#1fa8ff", text: "#ffe600", body: "#ff2e97", time: "#1fa8ff", crit: "#ff3355",
        keyFill: "#ffe600", keyRim: "#ffe600", keyInk: "#0a0514",
        head: "#ffe600", sub: "#ff2e97", marble: false
    },
    // Night Vision: green-ruled cards on the phosphor, the live one ruled
    // lit; dim app names and times, bright words, lit bodies, bright
    // outlined keys.
    nightvision: {
        fill: "transparent", rim: "#2b8a22", live: "#7dff6a", radius: 0,
        app: "#2fae2a", text: "#d6ffc9", body: "#7dff6a", time: "#2fae2a", crit: "#d6ffc9",
        keyFill: "transparent", keyRim: "#d6ffc9", keyInk: "#d6ffc9",
        head: "#d6ffc9", sub: "#7dff6a", marble: false
    },
    // Violet-ruled cards on the dot glass, the live one in a cyan tube;
    // cyan app names, pink words, cyan key outlines.
    tokyo: {
        fill: "transparent", rim: "#3c146e", live: "#2de2e6", radius: 3,
        app: "#2de2e6", text: "#ff3cac", body: "#b388ff", time: "#b388ff", crit: "#ff2a4a",
        keyFill: "transparent", keyRim: "#2de2e6", keyInk: "#2de2e6",
        head: "#b388ff", sub: "#2de2e6", marble: false
    },
    // Teal-ruled cards on the smoked glass, the live one in amber; amber
    // app names, cyan words, gunmetal keys.
    vfd: {
        fill: "transparent", rim: "#0a3c37", live: "#ff9f1c", radius: 0,
        app: "#ff9f1c", text: "#6fffe9", body: "#289682", time: "#289682", crit: "#ff5e3a",
        keyFill: "#3a3f42", keyRim: "#5a6064", keyInk: "#cfd6d9",
        head: "#6fffe9", sub: "#ff9f1c", marble: false
    }
};

// `flipped`: the era in its other tone (Tokens.flipped).
function get(era, flipped) {
    const l = looks[era] ?? null;
    return l && flipped ? Palettes.table(era, l, "nl") : l;
}

// The aero marble's colour for an app, steady across reloads.
function marble(app) {
    let h = 0;
    for (const ch of String(app))
        h = (h * 31 + ch.charCodeAt(0)) % 997;
    return ["#ff8a2a", "#1f7fd1", "#23963c"][h % 3];
}
