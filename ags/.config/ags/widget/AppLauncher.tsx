import app from "ags/gtk4/app"
import Astal from "gi://Astal?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import AstalApps from "gi://AstalApps"
import { onCleanup } from "ags"

// ━━━━━━━━━━━━━━━ APP LAUNCHER (replaces wofi/rofi) ━━━━━━━━━━━━━━━━
// Toggleable overlay that searches and launches desktop apps
// Closes on Escape, focus loss (click outside), and supports keyboard navigation

export function AppLauncher({ gdkmonitor }: { gdkmonitor: Gdk.Monitor }) {
  const apps = new AstalApps.Apps()

  let win: Astal.Window
  let entry: Gtk.Entry
  let listBox: Gtk.Box
  let selectedIndex = 0
  let currentResults: AstalApps.Application[] = []
  const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor

  const getResults = (text: string): AstalApps.Application[] => {
    return text.length > 0
      ? apps.fuzzy_query(text).slice(0, 12)
      : apps.get_list().slice(0, 12)
  }

  const highlightItem = (index: number) => {
    let child = listBox?.get_first_child()
    let i = 0
    while (child) {
      if (child instanceof Gtk.Button) {
        if (i === index) {
          child.add_css_class("selected")
        } else {
          child.remove_css_class("selected")
        }
        i++
      }
      child = child.get_next_sibling()
    }
  }

  const buildList = (items: AstalApps.Application[]) => {
    currentResults = items
    selectedIndex = 0

    // Clear existing children
    let child = listBox?.get_first_child()
    while (child) {
      const next = child.get_next_sibling()
      listBox.remove(child)
      child = next
    }

    if (items.length === 0) {
      const emptyBox = new Gtk.Box({
        orientation: Gtk.Orientation.VERTICAL,
        valign: Gtk.Align.CENTER,
        halign: Gtk.Align.CENTER,
        spacing: 8,
      })
      emptyBox.add_css_class("applauncher-empty")
      const emptyIcon = new Gtk.Image({
        iconName: "edit-find-symbolic",
        pixelSize: 48,
      })
      emptyIcon.add_css_class("applauncher-empty-icon")
      const emptyLabel = new Gtk.Label({ label: "No apps found" })
      emptyLabel.add_css_class("applauncher-empty-label")
      emptyBox.append(emptyIcon)
      emptyBox.append(emptyLabel)
      listBox.append(emptyBox)
      return
    }

    for (let idx = 0; idx < items.length; idx++) {
      const item = items[idx]
      const btn = new Gtk.Button()
      btn.add_css_class("applauncher-item")
      if (idx === 0) btn.add_css_class("selected")
      btn.connect("clicked", () => launch(item))

      const row = new Gtk.Box({ spacing: 12 })
      const iconBox = new Gtk.Box()
      iconBox.add_css_class("applauncher-icon-box")
      const icon = new Gtk.Image({
        iconName: item.iconName || "application-x-executable",
        pixelSize: 40,
      })
      icon.add_css_class("applauncher-icon")
      iconBox.append(icon)
      row.append(iconBox)

      const textCol = new Gtk.Box({
        orientation: Gtk.Orientation.VERTICAL,
        valign: Gtk.Align.CENTER,
        hexpand: true,
      })
      const nameLabel = new Gtk.Label({
        label: item.name,
        xalign: 0,
      })
      nameLabel.add_css_class("applauncher-name")
      textCol.append(nameLabel)

      if (item.description) {
        const descLabel = new Gtk.Label({
          label: item.description,
          xalign: 0,
          wrap: true,
          maxWidthChars: 50,
        })
        descLabel.add_css_class("applauncher-desc")
        textCol.append(descLabel)
      }

      row.append(textCol)

      // Show a subtle keyboard shortcut hint for first few items
      if (idx < 5) {
        const hint = new Gtk.Label({ label: `⏎` })
        hint.add_css_class("applauncher-hint")
        hint.visible = idx === 0
        row.append(hint)
      }

      btn.set_child(row)
      listBox.append(btn)
    }
  }

  const launch = (appItem: AstalApps.Application) => {
    appItem.launch()
    hide()
  }

  const hide = () => {
    win.visible = false
    if (entry) entry.text = ""
  }

  onCleanup(() => {
    win.destroy()
  })

  return (
    <window
      $={(self) => {
        win = self
        // Rebuild list when shown
        self.connect("notify::visible", () => {
          if (self.visible) {
            selectedIndex = 0
            buildList(getResults(""))
            if (entry) {
              entry.text = ""
              entry.grab_focus()
            }
          }
        })
        // Handle keyboard via GTK4 EventControllerKey
        const keyCtrl = new Gtk.EventControllerKey()
        keyCtrl.connect("key-pressed", (_ctrl, keyval) => {
          if (keyval === Gdk.KEY_Escape) {
            hide()
          } else if (keyval === Gdk.KEY_Down || keyval === Gdk.KEY_Tab) {
            if (currentResults.length > 0) {
              selectedIndex = (selectedIndex + 1) % currentResults.length
              highlightItem(selectedIndex)
            }
          } else if (keyval === Gdk.KEY_Up || keyval === Gdk.KEY_ISO_Left_Tab) {
            if (currentResults.length > 0) {
              selectedIndex = (selectedIndex - 1 + currentResults.length) % currentResults.length
              highlightItem(selectedIndex)
            }
          } else if (keyval === Gdk.KEY_Return || keyval === Gdk.KEY_KP_Enter) {
            if (currentResults.length > 0 && currentResults[selectedIndex]) {
              launch(currentResults[selectedIndex])
            }
          }
        })
        self.add_controller(keyCtrl)
      }}
      visible={false}
      namespace="ags-applauncher"
      name="applauncher"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.EXCLUSIVE}
      anchor={TOP | BOTTOM | LEFT | RIGHT}
      application={app}
    >
      {/* Clickable backdrop to close on click-outside */}
      <overlay>
        <button
          class="applauncher-backdrop"
          hexpand
          vexpand
          onClicked={() => hide()}
        >
          <box />
        </button>
        <box
          $type="overlay"
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.START}
          orientation={Gtk.Orientation.VERTICAL}
          class="applauncher"
        >
          {/* Header */}
          <box class="applauncher-header" spacing={8}>
            <image iconName="view-app-grid-symbolic" pixelSize={18} class="applauncher-header-icon" />
            <label label="Application Launcher" class="applauncher-header-title" />
          </box>

          {/* Search bar */}
          <box class="applauncher-search" spacing={10}>
            <image iconName="system-search-symbolic" pixelSize={18} class="applauncher-search-icon" />
            <entry
              $={(self) => {
                entry = self
              }}
              class="applauncher-entry"
              placeholderText="Type to search..."
              hexpand
              onChanged={({ text }) => {
                buildList(getResults(text ?? ""))
              }}
              onActivate={() => {
                if (currentResults.length > 0 && currentResults[selectedIndex]) {
                  launch(currentResults[selectedIndex])
                }
              }}
            />
          </box>

          {/* Results count */}
          <box class="applauncher-status">
            <label
              class="applauncher-count"
              $={(self) => {
                // Update on list changes
                const update = () => {
                  self.label = currentResults.length > 0
                    ? `${currentResults.length} apps`
                    : "No results"
                }
                update()
              }}
            />
          </box>

          {/* App list */}
          <Gtk.ScrolledWindow
            vexpand
            hscrollbarPolicy={Gtk.PolicyType.NEVER}
            maxContentHeight={480}
            propagateNaturalHeight
            class="applauncher-scroll"
          >
            <box
              $={(self) => {
                listBox = self
                buildList(getResults(""))
              }}
              orientation={Gtk.Orientation.VERTICAL}
              spacing={3}
              class="applauncher-list"
            />
          </Gtk.ScrolledWindow>

          {/* Footer hint */}
          <box class="applauncher-footer" spacing={12} halign={Gtk.Align.CENTER}>
            <box spacing={4}>
              <label label="↑↓" class="applauncher-key" />
              <label label="Navigate" class="applauncher-footer-text" />
            </box>
            <box spacing={4}>
              <label label="⏎" class="applauncher-key" />
              <label label="Launch" class="applauncher-footer-text" />
            </box>
            <box spacing={4}>
              <label label="Esc" class="applauncher-key" />
              <label label="Close" class="applauncher-footer-text" />
            </box>
          </box>
        </box>
      </overlay>
    </window>
  )
}
