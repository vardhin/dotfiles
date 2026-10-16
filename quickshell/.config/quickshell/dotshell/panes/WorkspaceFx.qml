import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

// Workspace switch as dissolving dots (services/WsFx.qml asks for it).
//
//   1. capture  a fresh ScreencopyView snapshots the focused screen (a new
//               one per switch: `hasContent` is its only "frame ready")
//   2. cover    the snapshot goes up on the overlay, crisp, so the screen
//               looks unchanged; two frames later the switch is dispatched
//   3. play     on Hyprland's workspace event the snapshot dissolves
//               (shaders/wsfx.frag) toward the direction of travel, showing
//               the new workspace underneath
//
// Adaptive speed: a switch right after the last one plays faster (down to
// minMs), so a run of switches or a scroll through workspaces keeps up. A
// switch during a dissolve snapshots the screen as it is, mid-dissolve, and
// carries on from there; the older run stays up until the new one covers it.
Scope {
    id: root

    readonly property int fullMs: 650
    readonly property int minMs: 200

    // Runs, oldest first: {id, screen, from, born, ms, dir, state}
    // state: capture | cover | armed | play
    property var runs: []
    property int serial: 0
    property real lastAt: 0
    property string pending: ""
    property real now: Date.now()

    // Delegates keyed by run id: a ListModel only adds and removes, where an
    // array model would rebuild every delegate (and lose its snapshot) on
    // each change.
    ListModel {
        id: runModel
    }
    onRunsChanged: {
        const ids = runs.map(r => r.id);
        for (let i = runModel.count - 1; i >= 0; i--)
            if (!ids.includes(runModel.get(i).rid))
                runModel.remove(i);
        const have = [];
        for (let i = 0; i < runModel.count; i++)
            have.push(runModel.get(i).rid);
        for (const r of runs)
            if (!have.includes(r.id))
                runModel.append({ rid: r.id });
    }
    function run(id: int): var {
        return runs.find(r => r.id === id) ?? null;
    }

    function update(id: int, fields: var): void {
        runs = runs.map(r => r.id === id ? Object.assign({}, r, fields) : r);
    }
    function drop(id: int): void {
        runs = runs.filter(r => r.id !== id);
    }
    function latest(): var {
        return runs.length ? runs[runs.length - 1] : null;
    }

    Connections {
        target: WsFx
        function onRequested(d) {
            root.start(d);
        }
    }

    function start(d: string): void {
        const t = Date.now();
        const ms = Math.max(minMs, Math.min(fullMs, (t - lastAt) * 0.8));
        lastAt = t;
        pending = d;
        const last = latest();
        // Still snapshotting for the last request: it takes this one instead.
        if (last && (last.state === "capture" || last.state === "cover")) {
            update(last.id, { ms: ms });
            return;
        }
        runs = runs.concat([{
                id: ++serial,
                screen: Hyprland.focusedMonitor?.name ?? "",
                from: Hyprland.focusedWorkspace?.id ?? 0,
                born: 0,
                ms: ms,
                dir: 1,
                state: "capture"
            }]);
        captureTimeout.restart();
    }

    function captured(id: int): void {
        const r = latest();
        if (!r || r.id !== id || r.state !== "capture")
            return;
        captureTimeout.stop();
        // The new snapshot covers whatever older run was still dissolving.
        runs = runs.filter(x => x.id >= id);
        update(id, { state: "cover" });
        cover.restart();
    }

    // Two frames for the overlay to show the snapshot, then switch.
    Timer {
        id: cover
        interval: 34
        onTriggered: {
            const r = root.latest();
            if (!r || r.state !== "cover")
                return;
            root.update(r.id, { state: "armed" });
            armTimeout.restart();
            Hyprland.dispatch(root.pending);
            root.pending = "";
        }
    }

    // No snapshot (screencopy failed): just switch.
    Timer {
        id: captureTimeout
        interval: 250
        onTriggered: {
            const r = root.latest();
            if (r && r.state === "capture")
                root.drop(r.id);
            if (root.pending)
                Hyprland.dispatch(root.pending);
            root.pending = "";
        }
    }

    // The switch did not move anything (already there): put the overlay away.
    Timer {
        id: armTimeout
        interval: 300
        onTriggered: {
            const r = root.latest();
            if (r && r.state === "armed")
                root.drop(r.id);
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "workspacev2")
                return;
            const r = root.latest();
            if (!r || r.state !== "armed")
                return;
            armTimeout.stop();
            const to = parseInt(event.data.split(",")[0]);
            // Named and special workspaces have negative ids: treat as rightward.
            const dir = to > 0 && r.from > 0 && to < r.from ? -1 : 1;
            root.update(r.id, { state: "play", born: Date.now(), dir: dir });
        }
    }

    // Finished runs leave.
    function prune(): void {
        const left = runs.filter(r => r.state !== "play" || now < r.born + r.ms);
        if (left.length !== runs.length)
            runs = left;
    }

    // One overlay per screen, kept mapped: idle it is 1x1 and empty (a new
    // window per switch would build a GL context and arrive late).
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property ShellScreen modelData
            screen: modelData

            readonly property var mine: root.runs.filter(r => r.screen === win.modelData.name)
            readonly property bool busy: mine.length > 0
            readonly property real dpr: win.devicePixelRatio ?? 1

            anchors {
                top: true
                left: true
            }
            implicitWidth: busy ? win.modelData.width : 1
            implicitHeight: busy ? win.modelData.height : 1
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "dotshell-wsfx"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            FrameAnimation {
                running: win.busy
                onTriggered: {
                    root.now = Date.now();
                    root.prune();
                }
            }

            Repeater {
                model: runModel

                Item {
                    id: run
                    required property int rid
                    readonly property var rec: root.run(rid)
                    readonly property bool here: rec !== null && rec.screen === win.modelData.name
                    visible: here
                    width: win.modelData.width
                    height: win.modelData.height

                    ScreencopyView {
                        id: view
                        anchors.fill: parent
                        captureSource: run.here ? win.modelData : null
                        live: false
                        paintCursor: false
                        onHasContentChanged: if (hasContent)
                            root.captured(run.rid)
                    }

                    ShaderEffectSource {
                        id: snap
                        sourceItem: view
                        hideSource: true
                        width: 0
                        height: 0
                        visible: false
                    }

                    ShaderEffect {
                        anchors.fill: parent
                        visible: view.hasContent
                        property variant source: snap
                        property size size: Qt.size(width * win.dpr, height * win.dpr)
                        property real pitch: (Tokens.pitch < 5 ? Tokens.pitch * 2 : Tokens.pitch) * win.dpr
                        property real t: run.rec?.state === "play" ? Math.max(0, Math.min(1, (root.now - run.rec.born) / run.rec.ms)) : -1
                        property real dir: run.rec?.dir ?? 1
                        property real dotSize: Tokens.dotSize
                        property real shape: Tokens.current.shape === "square" ? 1 : Tokens.current.shape === "bubble" ? 2 : 0
                        property real glow: Tokens.current.glow ?? 0.5
                        property color sparkColor: Tokens.slot1
                        property color glassColor: Tokens.glass
                        fragmentShader: Qt.resolvedUrl("../shaders/wsfx.frag.qsb")
                    }
                }
            }
        }
    }
}
