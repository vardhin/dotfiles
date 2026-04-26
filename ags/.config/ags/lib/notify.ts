import { execAsync } from "ags/process"

export type NotifyUrgency = "low" | "normal" | "critical"

export interface NotifyOptions {
  summary: string
  body?: string
  urgency?: NotifyUrgency
  icon?: string
  // App name shown by the notification daemon.
  appName?: string
  // ms; 0 means use the daemon's default; -1 means never expire.
  expireTime?: number
  // Stable id for replacing/updating an existing notification by tag.
  // libnotify's --replace-id wants a numeric id; for tag-based dedup we use --hint.
  replaceTag?: string
  // Categories help notification daemons group/icon-pick.
  category?: string
}

// Fire-and-forget. Goes through the system bus to whichever daemon is
// listening (AGS itself, in our case).
export function notify(opts: NotifyOptions): void {
  const args = ["notify-send"]

  if (opts.appName) args.push("--app-name", opts.appName)
  if (opts.urgency) args.push("--urgency", opts.urgency)
  if (opts.icon) args.push("--icon", opts.icon)
  if (typeof opts.expireTime === "number") args.push("--expire-time", `${opts.expireTime}`)
  if (opts.category) args.push("--category", opts.category)
  if (opts.replaceTag) args.push("--hint", `string:x-canonical-private-synchronous:${opts.replaceTag}`)

  args.push(opts.summary)
  if (opts.body) args.push(opts.body)

  execAsync(args).catch(console.error)
}
