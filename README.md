# SMPWORK

**A clean, unobfuscated rebuild of the MinimaHub Xeno hub — packaged for GitHub and ready to paste into the Xeno executor.**

SMPWORK is a compact, draggable overlay ("small screen") UI in the style of Delta.
It is a fresh, readable re-implementation of MinimaHub: no obfuscation, no
anti-debug / environment checks, no encrypted payloads. Everything you see in
the file is what actually runs.

> **Credits:** Akram Abbaoui & Amjad Nejjari
>
> **Disclaimer:** For educational / testing purposes only. Modifying the game
> client violates the Roblox Terms of Service and can get your account banned.
> You are responsible for how you use it.

---

## 📦 What is in this repo

| File | What it is |
| :--- | :--- |
| `SMPWORK.lua` | The hub itself. This is the file the loader downloads and runs. You can also paste it directly into the executor. |
| `loader.lua` | The GitHub launcher. Paste this into Xeno — it downloads `SMPWORK.lua` from GitHub and runs it. |
| `README.md` | This file. |
| `LICENSE` | MIT license. |

---

## 🚀 Features

### 👁️ Visuals
* **Box / Glow ESP** — highlights players, with a **wall check** that recolours the
  ESP when the target is behind geometry.
* **Skeleton ESP** — dynamic skeleton over players (R6 and R15).
* **Nametags** — display name, health and distance in studs.
* **Tracers** — lines from the bottom of your screen to each player.
* **Colour pickers** — eight-colour palette for visible, hidden, skeleton and tracer.

### 🎯 Aim
* **Aimbot** — smooth camera lock with adjustable **smoothing**, **max range** and an
  optional **wall check**.
* **Target selection** — `Head`, `UpperTorso` or `HumanoidRootPart`.
* **FOV ring** — a circle around your cursor with an adjustable radius.

### 🏃 Movement
* **Walk speed** and **Jump power** sliders.
* **Fly** (WASD + Space / LeftControl) with an adjustable speed.
* **Noclip**, **Infinite jump**, **Safewalk**.

### ⚔️ Combat
* **Hitbox expander** — enlarge enemy hitboxes (up to 30 studs).
* **Spinbot / anti-aim** — rotate your root so you are harder to hit.
* **Custom FOV** — camera field of view from 50 up to 120.

### 🛠️ Utils
* **Teleport to cursor** — button, or enable *Click teleport* and left-click in the world.
* **Server hopper** — jump to another public server through the Roblox API.
* **Auto reattach** — re-queue the script so it survives a teleport.
* **External loaders** — one-click buttons for Dex Explorer, Infinite Yield,
  Shadow Hub and UNC Checker (edit `EXTERNAL` in the script if a URL goes stale).
* **Danger zone** — `DESTROY SCRIPT` fully restores the game and removes the UI.

### 💾 Config & GitHub
* **Save / Load / Reset** the whole setup to `SMPWORK.json` in the executor workspace.
* **Check for updates** — compares the version published on GitHub with the running one.
* **Reload from GitHub** — pull the newest `SMPWORK.lua` and hot-restart the hub.

---

## ⌨️ Keybinds

| Action | Key / Input | Notes |
| :--- | :--- | :--- |
| **Toggle the UI** | `Right Control` | Shows / hides the overlay. |
| **Aimbot** | Hold `Right Mouse Button` | Requires *Enable aimbot* to be ON. |
| **Fly** | `W A S D` + `Space` / `LeftControl` | Requires *Fly* to be ON. |
| **Click teleport** | `Left Mouse Button` in the world | Requires *Click teleport* to be ON. |
| **Close the hub** | `x` in the title bar | Same as `DESTROY SCRIPT`. |

---

## 📖 Installation

### Option A — the GitHub launcher (recommended)

1. Open Roblox and join a game.
2. Open **Xeno**, go to the script tab.
3. Paste the whole of `loader.lua` into the editor.
4. Press **Execute**. The UI appears immediately.

`loader.lua` downloads the hub from GitHub every time, so once it is published
you only ever need to update the URL in the loader — never re-paste the hub.

### Option B — paste the hub directly

1. Open **Xeno**, go to the script tab.
2. Paste the whole of `SMPWORK.lua`.
3. Press **Execute**.

Works fine, but you will have to re-paste it after every update.

### Option C — one-liner

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USER/SMPWORK/main/SMPWORK.lua"))()
```

Replace `YOUR_USER` / `SMPWORK` with your own GitHub username and repository name.

---

## ☁️ Publishing to GitHub

1. Create a new repository on GitHub named `SMPWORK` (public or private, doesn't matter).
2. In this folder, run:

   ```bash
   git init
   git add SMPWORK.lua loader.lua README.md LICENSE
   git commit -m "SMPWORK v1.0.0"
   git branch -M main
   git remote add origin https://github.com/YOUR_USER/SMPWORK.git
   git push -u origin main
   ```

3. Copy the raw URL of `SMPWORK.lua`:
   `https://raw.githubusercontent.com/YOUR_USER/SMPWORK/main/SMPWORK.lua`

### The two places you must edit `YOUR_USER`

| File | Line / constant | What to change |
| :--- | :--- | :--- |
| `loader.lua` | `local SOURCES = { ... }` | Replace the URL with your raw `SMPWORK.lua` URL. |
| `SMPWORK.lua` | `local SELF_URL = ...` | Same URL — used by *auto reattach*, *check for updates* and *reload from GitHub*. |

Until `SELF_URL` is set, the loader prints
`SOURCES is not configured yet` and the hub shows
`Update check failed: SELF_URL is not configured yet`. Everything else still works.

---

## 🧹 Clean uninstall

`Config → DESTROY SCRIPT` (or the `x` in the title bar) instantly:

* Disconnects every loop and input connection.
* Deletes all Drawing elements (tracers, FOV ring, skeletons, boxes).
* Restores enemy hitboxes to their original size.
* Resets WalkSpeed, JumpPower and camera FOV.
* Removes the GUI.

---

## 🧰 Executor requirements

| API | Needed for | Required? |
| :--- | :--- | :--- |
| `Drawing` | ESP, tracers, skeleton, FOV ring | yes |
| `writefile` / `readfile` | config file, source cache | optional |
| `queue_on_teleport` | auto reattach | optional |
| `request` / `http_request` / `syn_request` | loader, update check | optional (needed for the loader) |
| `loadstring` | running downloaded source | yes for the loader |

Xeno, Synapse, Fluxus, Solara and Krnl all provide these.
If the executor has no `writefile`, the config buttons simply report it in the
status strip instead of crashing.

---

## 📄 License

MIT — see [LICENSE](LICENSE).

```
SMPWORK - a clean MinimaHub rebuild
Copyright (c) 2024 Akram Abbaoui & Amjad Nejjari
```
