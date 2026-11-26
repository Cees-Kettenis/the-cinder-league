# Install and run

## Play the desktop alpha

Download the archive for your system from the [Alpha 0.1 release](https://github.com/Cees-Kettenis/the-cinder-league/releases/tag/v0.1-alpha). Extract the entire archive first.

| Platform | Archive | What to open |
| --- | --- | --- |
| Linux x86-64 | `The-Cinder-League-0.1-alpha-linux-x86_64.tar.gz` | Run `./The-Cinder-League.x86_64` from the extracted folder. |
| Windows x86-64 | `The-Cinder-League-0.1-alpha-windows-x86_64.zip` | Open `The Cinder League.exe` with `The Cinder League.pck` beside it. |
| macOS, Intel and Apple Silicon | `The-Cinder-League-0.1-alpha-macos-universal.zip` | Open `The Cinder League.app`. The alpha has an ad-hoc signature and no notarization, so macOS may block it. |

The release bundles include the game runtime. The release page also provides `SHA256SUMS.txt` for checking the downloads.

The desktop download uses the published Alpha 0.1 tag. The screenshots and guides describe the current source checkout.

## Run from source

1. Install the **Standard** [Godot 4.7.2 editor](https://godotengine.org/download/archive/4.7.2-stable/).
2. Clone the [game repository](https://github.com/Cees-Kettenis/the-cinder-league) or extract its source ZIP.
3. In Godot’s Project Manager, choose **Import** and select [project.godot](../project.godot). Wait for the asset import, then press **F5** to play.

If `godot` is on your PATH, you can import and launch from the repository root.

```bash
godot --headless --path . --import
godot --path .
```

For editor work and source play, the Standard editor is enough. Install matching export templates when [building standalone packages](contributing/desktop-builds.md).

Next up is [your first bout](how-to-play.md). If you’re editing the game, see [Contributing](../CONTRIBUTING.md).
