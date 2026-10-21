.pragma library

// Era skins for desktop panels: the hardware a panel is built as, not its
// colors (those are the era's tubes, Eras.qml). Ported from the panel design
// canvas ("Dot Shell home panels"): each era's frame, whether it has a title
// band, and the words its panels use. Layouts (Templates.js) never branch on
// era; they read words as {~key} and the frame is drawn around them
// (DeskPanel.qml). Actions keep their bindings whatever the word says.
//
//   frame    ring      one-dot LED ring (animated by LedFx)
//            double    two rings, two dots apart (a double rule, brass rims)
//            plain     one still ring
//            bezel     a two-dot dim bezel, then the ring (car stereo, handheld)
//            brackets  corner brackets only (a gunsight)
//            bevel     light top-left, dark bottom-right (a 90s window)
//   header   true: a title band across the top (the panel's `head` word)
//   round    corner radius in dots for rect panels (0 = square)
//   upper    words in capitals
//   flaps    split-flap rows: a dark seam through every list row
//
// Words: `all` applies to every panel; then per template. Missing words fall
// back to the template's own defaults (Templates.js, `words`).
var eras = {
    tokyo: {
        frame: "ring", header: false, round: 5, upper: true,
        all: { del: "DELETE" },
        todo: { title: "TODAY", off: "o" },
        messages: { title: "MESSAGES" },
        dock: { title: "RUNNING" }
    },
    nineties: {
        frame: "ring", header: false, round: 2, upper: true,
        all: { del: "TRASH" },
        todo: { title: "TO DO", add: "+ NEW THING TO DO" },
        messages: { title: "PAGES", icon: "@" },
        screenshots: { title: "SNAPS" },
        dock: { title: "OPEN" }
    },
    vfd: {
        frame: "bezel", header: false, round: 1, upper: true,
        all: { del: "ERASE" },
        media: { lyr: "LYR · LRCLIB" },
        messages: { title: "MESSAGES", icon: "MSG" },
        caffeine: { icon: "WARM" },
        files: { find: "FIND" },
        clipboard: { icon: "M1" },
        todo: { title: "TODAY" },
        dock: { title: "CH ACTIVE" }
    },
    aero: {
        frame: "ring", header: false, round: 6, upper: false,
        all: { del: "Delete" },
        media: { lyr: "Lyrics" },
        clock: { foot: "No appointments today" },
        messages: { title: "Notifications" },
        files: { find: "Search" },
        todo: { title: "Today", add: "+ Add a task" },
        screenshots: { title: "Screenshots" },
        dock: { title: "Open windows" }
    },
    nixie: {
        frame: "double", header: false, round: 1, upper: false,
        all: { del: "Strike" },
        messages: { title: "Telegrams" },
        todo: { title: "Today", on: "x", add: "+ type a new line" },
        screenshots: { title: "Contact sheet" },
        dock: { title: "Lit tubes" }
    },
    flap: {
        frame: "plain", header: true, round: 0, upper: true, flaps: true,
        all: { del: "CANCEL", head: "{name}", headR: "● LIVE" },
        media: { head: "NOW PLAYING", headR: "● ON AIR" },
        clock: { head: "DEPARTURES" },
        workspaces: { head: "PLATFORMS" },
        system: { head: "SYSTEM STATUS", headR: "● NOMINAL" },
        battery: { head: "POWER · 24 HOURS" },
        messages: { head: "ARRIVALS · MESSAGES", icon: "MSG" },
        capture: { head: "STUDIO · CAPTURE", headR: "● READY" },
        caffeine: { head: "SCREEN · STAY AWAKE", headR: "", icon: "AWAKE" },
        tray: { head: "SERVICES" },
        downloads: { head: "ARRIVALS · FILES" },
        files: { head: "DESTINATIONS", headR: "RECENT", find: "FIND" },
        clipboard: { head: "COPIED · RECENT", icon: "CLIP" },
        todo: { head: "TODAY'S RUNS", on: "DONE", off: "DUE", add: "+ ADD A RUN" },
        screenshots: { head: "LAST CAPTURES" },
        dock: { title: "NOW BOARDING" }
    },
    nightvision: {
        frame: "brackets", header: false, round: 0, upper: true,
        all: { del: "BURN" },
        media: { lyr: "AUDIO · TRANSCRIPT" },
        clock: { foot: "NO TASKING · STANDBY" },
        messages: { title: "COMMS LOG", icon: "RX" },
        caffeine: { icon: "SENTRY" },
        files: { find: "QUERY" },
        clipboard: { icon: "ICPT" },
        todo: { title: "MISSION OBJECTIVES", off: "o", add: "+ ASSIGN OBJECTIVE" },
        screenshots: { title: "RECON IMAGERY" },
        dock: { title: "ACTIVE UNITS" }
    },
    vapor: {
        frame: "bevel", header: true, round: 0, upper: false,
        all: { del: "Recycle", head: "{name}.exe", headR: "_ □ ×" },
        media: { head: "now_playing.exe", lyr: "lyrics.txt" },
        clock: { head: "date_time.exe" },
        workspaces: { head: "pager.exe" },
        system: { head: "taskmgr.exe" },
        battery: { head: "power_meter.exe" },
        messages: { head: "inbox.exe", title: "Inbox" },
        capture: { head: "capture.exe" },
        caffeine: { head: "display.cpl" },
        tray: { head: "systray.exe" },
        downloads: { head: "downloads.exe" },
        files: { head: "My Computer" },
        clipboard: { head: "clipbrd.exe" },
        todo: { head: "todo.txt - Notepad" },
        screenshots: { head: "shots.exe" },
        dock: { title: "Taskbar" }
    },
    blueprint: {
        frame: "plain", header: true, round: 0, upper: true,
        all: { del: "VOID", head: "SHEET — {name}", headR: "REV A" },
        media: { head: "SHEET 1 OF 1", headR: "NOW PLAYING · REV A", lyr: "NOTE 3 — LYRICS" },
        clock: { head: "SHEET 2 — CALENDAR" },
        workspaces: { head: "SHEET 3 — FLOOR PLANS" },
        system: { head: "SHEET 4 — LOAD SCHEDULE" },
        battery: { head: "SHEET 5 — DISCHARGE" },
        messages: { head: "SHEET 6 — REVISION NOTES", headR: "REV C", title: "NOTES" },
        capture: { head: "SHEET 7 — CAPTURE" },
        caffeine: { head: "SHEET 8 — IDLE CIRCUIT", icon: "S1" },
        tray: { head: "LEGEND — SYMBOLS", headR: "SHT 9" },
        downloads: { head: "SHEET 10 — ROUTING" },
        files: { head: "DRAWING INDEX", headR: "SHT 11", find: "LOOKUP" },
        clipboard: { head: "CLIPPINGS — NOTES", headR: "SHT 12", icon: "N1" },
        todo: { head: "PUNCH LIST — TODAY", headR: "SHT 13", on: "x" },
        screenshots: { head: "SHEET 14 — CAPTURES", headR: "REV C" },
        dock: { title: "ITEM SCHEDULE" }
    }
};

function get(era) {
    return eras[era] || eras.tokyo;
}

// Every word a template's layout may ask for, for one era: the template's
// defaults, then the era's `all`, then the era's words for that template.
// {name} in a word is the template's display name.
function words(era, template) {
    const e = get(era);
    const t = template || {};
    const out = Object.assign({ del: "DELETE", ok: "OK", head: "{name}", headR: "" }, t.words || {}, e.all || {}, e[t.name] || {});
    const name = t.title || t.name || "";
    for (const k in out) {
        let v = String(out[k]).replace("{name}", e.upper ? name.toUpperCase() : name.toLowerCase());
        if (e.upper)
            v = v.toUpperCase();
        out[k] = v;
    }
    return out;
}
