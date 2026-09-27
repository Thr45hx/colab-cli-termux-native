#!/data/data/com.termux/files/usr/bin/bash
# uninstall.sh — remove the colab launcher + venv.
# Leaves the shared glibc runtime (glibc-runner / python-glibc / libsqlite-glibc)
# in place, since other native Termux tools rely on it.
set -eu
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
rm -f "$PREFIX/bin/colab"
rm -rf "${COLAB_CLI_VENV:-$HOME/.local/share/colab-cli-termux/venv}" "$HOME/.local/share/colab-cli-termux"
echo "[colab-native] removed launcher + venv."
echo "[colab-native] session tokens (if any) remain in ~/.config/colab-cli/ — delete manually to fully sign out."
echo "[colab-native] glibc runtime packages left installed (shared with other native tools)."
