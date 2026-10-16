-- Programs and paths every other module uses. Kept in one global table, D,
-- so modules stay independent of load order.

D = D or {}

D.terminal   = "ghostty"
D.editor     = D.terminal .. " -e nano"
D.browser    = "firefox"
-- libadwaita, so it takes the era colors Dot Shell exports to gtk-4.0/gtk.css.
D.files      = "nautilus --new-window"
D.mod        = "SUPER"
D.scripts    = "~/.config/hypr/scripts"
-- Dot Shell by path: `qs -c dotshell` is skipped if ~/.config/quickshell/shell.qml exists.
D.dotshell   = "qs -p ~/.config/quickshell/dotshell"

-- `qs ipc call …` against Dot Shell.
function D.ipc(args)
    return D.dotshell .. " ipc call " .. args
end
