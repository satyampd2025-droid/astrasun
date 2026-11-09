# Glue Box (VST3)

A stereo bus compressor plugin, ported from the browser prototype.

**Controls:** Threshold, Ratio, Attack, Release, Knee, Makeup, Link, Mix, Saturation,
plus Thrust (Normal/Med/Loud), Tone (Old/Normal/New), Type (feed-forward/feed-back),
Sat character (Warm/Clean/Hard) and Bypass. The window has a VU meter (0 VU = -18 dBFS)
and a gain-reduction meter that shows exactly how many dB are being removed.

Built with [JUCE](https://juce.com) 8.0.9. Check JUCE's licence terms before distributing the plugin.

## Get the plugin (no local setup)

Push to GitHub, open **Actions → Build Glue Box VST3**, and download the artifact for your
system (Windows, macOS or Linux). Copy the `Glue Box.vst3` folder to:

| System  | VST3 folder |
|---------|-------------|
| Windows | `C:\Program Files\Common Files\VST3` |
| macOS   | `~/Library/Audio/Plug-Ins/VST3` |
| Linux   | `~/.vst3` |

On macOS the first load may be blocked because the build is not code-signed. Allow it under
System Settings → Privacy & Security, or run `xattr -cr "Glue Box.vst3"`.

## Build locally

You need CMake 3.22+, a C++17 compiler, and on Linux the X11, FreeType and Fontconfig dev packages.

```bash
cd glue-box-vst
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

The plugin appears in `build/GlueBox_artefacts/Release/VST3/`.
