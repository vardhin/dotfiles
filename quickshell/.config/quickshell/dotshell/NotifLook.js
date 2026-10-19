.pragma library

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

function get(era) {
    return looks[era] ?? null;
}

// The aero marble's colour for an app, steady across reloads.
function marble(app) {
    let h = 0;
    for (const ch of String(app))
        h = (h * 31 + ch.charCodeAt(0)) % 997;
    return ["#ff8a2a", "#1f7fd1", "#23963c"][h % 3];
}
