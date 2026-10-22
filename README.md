# MinimaHub

A lightweight, performance-optimized utility and hub script for Roblox. Minimal Hub focuses on providing essential features like ESP, Aimbot, and Player modifications with a clean, unobtrusive user interface. The script separates visual rendering from physics loops to eliminate game stuttering.

⚠️ **Disclaimer:** This script is designed for educational/testing purposes. Modifying the game client violates Roblox's Terms of Service and may result in account moderation or bans. Use at your own risk.

---

## 🚀 Features

### 👁️ Visuals
* **Glow ESP:** Dynamic character highlighting. Includes a wall-check feature that changes the ESP color based on line-of-sight visibility.
* **Skeleton ESP:** Draws a dynamic skeleton over players (supports both R6 and R15 rigs).
* **Nametags:** Displays player names, current health, and distance in studs.
* **Tracers:** Draws line tracers from the bottom of your screen to other players.
* **Customization:** Fully customizable RGB color pickers for visible, invisible, and skeleton elements.

### 🎯 Aimbot
* **Aim Assist:** Smooth camera locking onto targets.
* **Custom Targeting:** Select between *Head*, *HumanoidRootPart*, or *UpperTorso*.
* **Advanced Checks:** Includes Wallcheck and customizable smoothing/lerp.
* **FOV Ring:** Visual Field of View circle around your cursor with adjustable radius.

### 🏃 Player Modifications
* **Movement:** Override and adjust standard WalkSpeed and JumpPower.
* **Traversal:** Fly Mode (with adjustable speed), Noclip (walk through walls), and Infinite Jump.
* **Safewalk:** Automatically stops your character from walking off edges.

### ⚔️ Combat & Environment
* **Hitbox Expander:** Enlarge enemy hitboxes (up to 30 studs) for incredibly easy targeting.
* **Spinbot / Anti-Aim:** Manipulate your character's root orientation to make yourself harder to hit.
* **Custom Camera FOV:** Adjust the camera field of view from 70 up to 120.

### 🛠️ Utilities
* **Click Teleport:** Teleport exactly to where your mouse cursor is pointing.
* **Server Hopper:** Scrapes the Roblox API to instantly join a new, well-populated public server.
* **Auto Reattach:** Automatically queues the script to re-execute when teleporting between places/rejoining.
* **External Hubs Built-in:** Quick-load popular external scripts with one click:
  * Shadow Hub
  * Dex Explorer
  * Infinite Yield
  * UNC Checker
* **Config System:** Automatically saves and loads your setup to a local `.json` file.

---

## ⌨️ Default Keybinds

| Action | Key / Input | Notes |
| :--- | :--- | :--- |
| **Toggle UI** | `Right Control` | Shows or hides the main Minimal Hub menu. |
| **Click Teleport** | `T` | Requires "Click TP" to be toggled ON in the Utility tab. |
| **Use Aimbot** | `Hold Right Mouse Button` | Requires "Enable Aimbot" to be toggled ON. |

---

## 📖 Usage / Installation

1. Copy the loadstring script.
   ```lua
   loadstring(game:HttpGet("https://raw.githubusercontent.com/Wakype/MinimaHub/main/Abbaoui-and-Nejjari.lua"))()
   ```
2. Launch a Roblox game.
3. Open your preferred Roblox executor.
   * *Note: For all features to work, your executor must support the `Drawing` API, `writefile/readfile`, and `queue_on_teleport` (e.g., Synapse, Krnl, Fluxus, Solara, Xeno, etc).*
4. Paste the loadstring script into the executor and hit **Execute**.
5. The UI will pop up automatically. Press `Right Control` to hide or show it.

---

## 🧹 Clean Uninstallation
Minimal Hub is built with a strict cleanup function. If you want to stop using the script without restarting your game, navigate to the **Config** tab and click **DESTROY SCRIPT**. 

This will instantly:
* Disconnect all active loops and input connections.
* Delete all Drawing elements (Tracers, FOV, Skeletons).
* Restore all altered player hitboxes to their original sizes.
* Reset your character's WalkSpeed, JumpPower, and Camera FOV to default.
* Remove the GUI entirely.
