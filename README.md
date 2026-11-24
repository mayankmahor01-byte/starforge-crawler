# STARFORGE CRAWLER — Vertical Slice 1 (EYES INTERACTIVE)

A stylized 2.5D physics vehicle crawler built in **Godot 4.3 (GL Compatibility)** with procedural beveled 3D meshes, cartoon-PBR rim-lighting shaders, raycast spring-damper suspension, mid-air flip & perfect-landing dopamine loops, procedural `AudioStreamGenerator` sound design, and mobile touch controls.

## Controls
- **Mobile (Touch):** Bottom-left **BRAKE / TILT**, bottom-right **GAS / TILT** + **⚡ BOOST**
- **Desktop Testing:** `A / Left` (Brake / Frontflip), `D / Right` (Gas / Backflip), `Space` (Ion Boost), `R` (Instant Restart)

---

## 4 Steps to Build & Download Your Android `.apk` via GitHub Actions

1. **Create a new empty repository** on GitHub (e.g., `starforge-crawler`).
2. **Unzip this archive** and open PowerShell / Terminal inside the `starforge-crawler` folder.
3. **Push to GitHub:**
   ```bash
   git init
   git add .
   git commit -m "Starforge Crawler Vertical Slice 1"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/starforge-crawler.git
   git push -u origin main
   ```
4. **Download the APK:** Open your repo on GitHub → click the **Actions** tab → open the completed **"Build Starforge Crawler Android APK"** workflow run → download **`starforge-crawler-vs1-apk`** under **Artifacts**, unzip it, and install `starforge-crawler.apk` on your Android phone.
