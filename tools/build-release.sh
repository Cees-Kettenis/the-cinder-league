#!/usr/bin/env bash
set -euo pipefail

project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
godot_bin=${GODOT_BIN:-godot}
destination=${1:-$project/dist}

project_version=$(sed -n 's/^config\/version="\([^"]*\)"$/\1/p' "$project/project.godot")
if [[ ! $project_version =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Set a numeric config/version in project.godot for the desktop bundle." >&2
  exit 1
fi
version="$project_version-alpha"
if [[ ${GITHUB_EVENT_NAME:-} == push && ${GITHUB_REF_TYPE:-} == tag && ${GITHUB_REF_NAME:-} != "v$version" ]]; then
  echo "Tag ${GITHUB_REF_NAME:-} does not match the project version v$version." >&2
  exit 1
fi

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
install -d "$destination" "$scratch/packages" "$scratch/notices"
destination=$(cd -- "$destination" && pwd)
prefix="The-Cinder-League-$version"

run_checked() {
  local log="$scratch/godot.log"
  if ! "$@" >"$log" 2>&1 || grep -Eq 'SCRIPT ERROR:|^ERROR:' "$log"; then
    cat "$log" >&2
    exit 1
  fi
}

engine_build=$("$godot_bin" --version)
engine_version=${engine_build%%.stable.*}
for notice in LICENSE COPYRIGHT; do
  curl --fail --silent --show-error --location --retry 4 \
    "https://raw.githubusercontent.com/godotengine/godot/$engine_version-stable/$notice.txt" \
    -o "$scratch/notices/Godot-$notice.txt"
done
cp "$project/docs/licenses/FluidR3-LICENSE.txt" "$scratch/notices/"

echo "Importing assets and running playtest regressions"
run_checked "$godot_bin" --headless --path "$project" --import
run_checked "$godot_bin" --headless --path "$project" --script tools/check_content.gd
run_checked env XDG_DATA_HOME="$scratch/test-data" \
  "$godot_bin" --headless --path "$project" --script tests/playtest.gd

cat > "$scratch/notices/START-HERE.txt" <<EOF
The Cinder League $version

Extract the whole archive before launching the game.

Linux x86-64: Run ./The-Cinder-League.x86_64.
Windows x86-64: Run The Cinder League.exe and keep its .pck beside it.
macOS: Open The Cinder League.app on Intel or Apple Silicon.
The macOS alpha uses an ad-hoc signature and has no notarization.
EOF

echo "Exporting Linux x86-64"
linux_folder="$scratch/linux/The-Cinder-League"
mkdir -p "$linux_folder"
cp "$scratch/notices/"* "$linux_folder/"
linux_bin="$linux_folder/The-Cinder-League.x86_64"
run_checked "$godot_bin" --headless --path "$project" --export-release "Linux x86_64" "$linux_bin"
test -x "$linux_bin"
run_checked env XDG_DATA_HOME="$scratch/smoke-data" "$linux_bin" --headless --quit-after 5
tar -czf "$scratch/packages/$prefix-linux-x86_64.tar.gz" -C "$scratch/linux" The-Cinder-League

echo "Exporting Windows x86-64"
windows_folder="$scratch/windows/The-Cinder-League"
mkdir -p "$windows_folder"
cp "$scratch/notices/"* "$windows_folder/"
windows_bin="$windows_folder/The Cinder League.exe"
windows_data="$windows_folder/The Cinder League.pck"
run_checked "$godot_bin" --headless --path "$project" --export-release "Windows x86_64" "$windows_bin"
test -s "$windows_bin"
test -s "$windows_data"
(cd "$scratch/windows" && zip -qr "$scratch/packages/$prefix-windows-x86_64.zip" The-Cinder-League)

echo "Exporting macOS Universal"
mac_folder="$scratch/macos/The-Cinder-League"
mkdir -p "$mac_folder"
cp "$scratch/notices/"* "$mac_folder/"
mac_app="$mac_folder/The Cinder League.app"
run_checked "$godot_bin" --headless --path "$project" --export-release "macOS Universal" "$mac_app"
test -s "$mac_app/Contents/Info.plist"
(cd "$scratch/macos" && zip -qry "$scratch/packages/$prefix-macos-universal.zip" The-Cinder-League)

(
  cd "$scratch/packages"
  sha256sum "$prefix-"* > SHA256SUMS.txt
  cp -- "$prefix-"* SHA256SUMS.txt "$destination/"
)
printf 'Built %s in %s\n' "$version" "$destination"
