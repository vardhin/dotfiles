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
