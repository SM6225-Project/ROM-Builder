# ROM Builder 🔧

A shell script that automates the process of adapting Android device trees for custom ROMs — from downloading trees and cloning dependencies, to signing keys, adding Moto Camera 4, and launching the build. All through interactive menus.

---

## What it does

- **Auto-detects the ROM** from your `vendor/` folder (LineageOS, VoltageOS, crDroid, rising, etc.)
- **Downloads device trees** from LineageOS GitHub and recursively clones all dependencies listed in `lineage.dependencies` (supports multi-level chains like `rhode → sm6225-common → hardware/motorola → ...`)
- **Downloads vendor trees** — either by pasting a full URL or building it step by step (supports both GitHub and GitLab)
- **Generates signing keys** — supports LineageOS, crDroid and GenesisOS key generation
- **Adapts device trees** — renames `.mk` files and replaces the old ROM prefix with the new one across the tree (skips `device.mk` and `BoardConfig.mk` to avoid breaking package names)
- **Adds Moto Camera 4** support with all required repositories and flags
- **Fixes sepolicy** conflicts caused by Moto Camera duplicate entries
- **Launches the build** with `lunch` and `make bacon` (falls back to `make otapackage`)

---

## Requirements

- A fully synced Android source tree (`repo sync` done)
- `git`, `python3` and `bash` available
- Run the script from the **root of your Android source** (same folder as `build/envsetup.sh`)

---

## Usage

```bash
chmod +x rom_builder.sh
./rom_builder.sh
```

---

## Navigation

| Key | Action |
|-----|--------|
| `↑` / `↓` | Move between options |
| `Space` | Select / deselect (on multi-select menus) |
| `Enter` | Confirm |

---

## Full step by step

### 1. ROM Detection
Automatically reads your `vendor/` folder and maps it to a prefix (e.g. `voltage`, `lineage`, `ev`). If it can't detect, it asks you to pick manually.

### 2. Download device trees (optional)
If you don't have your device trees yet, the script can download them. For each device:
- Asks for **brand**, **codename** and **LineageOS branch** (e.g. `lineage-22.2`)
- Brand input is validated — if you mistype (e.g. `mototola`), it warns you and gives 3 attempts
- Clones from `github.com/LineageOS/android_device_brand_codename`
- Reads `lineage.dependencies` and clones all dependencies recursively until the chain ends

### 3. Brand and device selection
Lists everything found under `device/` and lets you pick one or more devices at once with the multi-select menu.

### 4. Vendor trees (optional)
For each selected device, asks if you have a vendor tree. If yes:
- **Paste full URL** — asks for URL, branch and destination path
- **Build manually** — asks for platform (GitHub or GitLab), username, repo name, branch and path

### 5. Signing keys
Asks which type of keys to generate:

| Option | Where keys are saved | Adds `-include` to device.mk? |
|--------|---------------------|-------------------------------|
| LineageOS keys | `~/.android-certs` | No |
| crDroid keys | `vendor/lineage-priv/keys` | Yes |
| GenesisOS keys | `vendor/ROMNAME/signing/keys` | No |

> Requires `development/tools/make_key` — only available after a full `repo sync`.

### 6. Tree adaptation
For each selected device:
- Detects the current prefix in the tree (e.g. `lineage`)
- Renames `lineage_device.mk` → `voltage_device.mk`
- Replaces all occurrences of the old prefix inside `.mk` and `.bp` files
- Updates `AndroidProducts.mk` to point to the renamed file

### 7. Moto Camera 4 (optional)
Clones all required repositories and patches `device.mk` with the necessary flags. Also fixes sepolicy duplicate entries that cause build errors.

> **Note:** Moto Camera 4 repos are specific to the **bengal (SM6225)** chipset. Skip this step if your device uses a different chipset.

### 8. Android version prefix
Pick from a list of known prefixes:

| Prefix | Version |
|--------|---------|
| `bp4a` | Android 16 QPR2 |
| `bp2a` | Android 16 QPR1 |
| `bp1a` | Android 16 |
| `ap4a` | Android 15 QPR3 |
| `ap1a` | Android 15 |
| `up1a` | Android 14 |
| `tp1a` | Android 13 |
| `sp1a` | Android 12 |
| ... | and more |

Or type it manually if yours isn't listed.

### 9. Build variant
Pick between `userdebug`, `user` or `eng`.

### 10. Build
Sources `build/envsetup.sh`, runs `lunch` and starts the build. You choose how many threads to use (defaults to all available cores).

---

## Supported ROMs (auto-detected)

| Vendor folder | Prefix |
|---------------|--------|
| `lineage` | `lineage` |
| `voltage` | `voltage` |
| `evolution` | `ev` |
| `rising` | `rising` |
| `spark` | `spark` |
| `havoc` | `havoc` |
| `arrow` | `arrow` |
| `bliss` | `bliss` |
| `axion` | `axion` |
| `crdroid` | `lineage` |
| `pixelexperience` | `aosp` |

If your ROM isn't listed, the script will ask you to select the vendor manually and type the prefix yourself.

---

## Notes

- If you run the script more than once on the same tree, it skips steps that were already done (existing repos, already renamed files, already added flags, etc.)
- The script targets **LineageOS-based trees** for the download step. Trees from other sources still work for adaptation and build
- `AndroidProducts.mk` is updated automatically so the build system finds the renamed `.mk` file
- `device.mk` and `BoardConfig.mk` are intentionally excluded from prefix substitution to avoid breaking hardware package names

---

## Tested on

- **LunarisAOSP** (Android 16 QPR2) ✅
- **LineageOS** (Android 15 QPR2) ✅
- Devices: `devon`, `hawao`, `rhode` (Motorola SM6225 / bengal family)

---
