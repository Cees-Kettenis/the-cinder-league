# Desktop builds

See [Install and run](../install.md) to play a published build.

## Build on GitHub

Select **Actions → Desktop release → Run workflow** and choose the branch to build. The job imports assets, runs the content and playtest checks, and exports Linux x86-64, Windows x86-64, and macOS Universal. Download the three packages and their SHA-256 checksums from the `cinder-league-desktop` artifact.

The [release workflow](../../.github/workflows/release.yml) pins Godot and its export templates. A branch build uploads an artifact. A push of a matching `v*-alpha` tag publishes a prerelease after all exports pass. For a new release, set the intended numeric version in [project.godot](../../project.godot) and tag that commit with the same version, prefixed by `v` and suffixed by `-alpha`. For example, version `0.2` uses tag `v0.2-alpha`.

## Build locally on Linux

Install the Standard Godot editor and its matching export templates. Ensure Bash, `curl`, `zip`, `tar`, and `sha256sum` are available. Run the [build script](../../tools/build-release.sh) from the repository root.

```bash
bash tools/build-release.sh
```

The archives and checksums are written to the ignored `dist/` folder. Pass a directory argument to build elsewhere. Set `GODOT_BIN` if the editor isn’t available as `godot`.

## Exported content

The [export presets](../../export_presets.cfg) exclude documentation, tests, tools, and local build output. Put guide screenshots under `docs/assets/`, where `.gdignore` also keeps them out of Godot’s imports. The build script copies the third-party notices into the archives alongside the game.
