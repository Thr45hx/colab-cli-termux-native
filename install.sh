#!/data/data/com.termux/files/usr/bin/bash
# install.sh — Google Colab CLI, native on Termux (aarch64). No proot, no root.
#
# The Colab CLI is a thin, pure-Python client — all real compute is REMOTE on
# Colab VMs (`colab run` provisions a VM, runs your script, retrieves outputs,
# and tears the VM down). So there is no binary to patchelf. The only walls are
# its compiled *dependencies* (cryptography, pyarrow), which have no working
# Termux/bionic wheels. Fix: run it on the Termux *glibc* Python, where those
# install as prebuilt manylinux aarch64 wheels with zero source builds.
set -eu

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
GPY="$PREFIX/glibc/bin/python3.12"
VENV="${COLAB_CLI_VENV:-$HOME/.local/share/colab-cli-termux/venv}"
LAUNCHER="$PREFIX/bin/colab"

say(){ printf '\033[1;36m[colab-native]\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31m[colab-native] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

command -v pkg >/dev/null 2>&1 || die "This installer is for Termux (no 'pkg' found)."

# 1) glibc runtime: the runner, the glibc Python 3.12, and glibc sqlite.
#    filelock.ReadWriteLock (used by the CLI) is sqlite-backed, so the glibc
#    _sqlite3 extension needs libsqlite3.so.0 from libsqlite-glibc — without it
#    every real command dies with "TypeError: 'NoneType' object is not callable".
say "Installing glibc runtime (glibc-runner, python-glibc, libsqlite-glibc)…"
pkg install -y glibc-repo >/dev/null 2>&1 || true
pkg install -y glibc-runner python-glibc python-pip-glibc libsqlite-glibc >/dev/null 2>&1 \
  || die "failed to install glibc packages (glibc-runner / python-glibc / libsqlite-glibc)."
command -v grun >/dev/null 2>&1 || die "'grun' (glibc-runner) not on PATH after install."
[ -x "$GPY" ] || die "glibc Python not found at $GPY"

# 2) venv + the CLI. cryptography / pyarrow / pydantic-core arrive as manylinux wheels.
if [ ! -x "$VENV/bin/python" ]; then
  say "Creating glibc venv at $VENV…"
  mkdir -p "$(dirname "$VENV")"
  grun "$GPY" -m venv "$VENV" || die "venv creation failed."
fi
say "Installing google-colab-cli (prebuilt wheels, no source builds)…"
grun "$VENV/bin/python" -m pip install -q --upgrade pip >/dev/null 2>&1 || true
grun "$VENV/bin/python" -m pip install -q --upgrade google-colab-cli \
  || die "pip install google-colab-cli failed."

# 3) launcher on PATH
say "Installing launcher: $LAUNCHER"
cat > "$LAUNCHER" <<LADEF
#!/data/data/com.termux/files/usr/bin/bash
# Native Termux launcher for the Google Colab CLI (runs on the glibc Python via grun).
VENV="$VENV"
exec grun "\$VENV/bin/python" "\$VENV/bin/colab" "\$@"
LADEF
chmod +x "$LAUNCHER"

# 4) verify (offline; does not touch your Google account)
V="$("$LAUNCHER" version 2>&1 | grep -i '^version' | head -1 || true)"
[ -n "$V" ] || die "installed, but 'colab version' did not run — try: grun $VENV/bin/python $VENV/bin/colab version"
say "OK — $V"
say ""
say "Native install complete — no proot in the runtime path."
say "First use needs a one-time Google sign-in (out-of-band, headless-friendly):"
say "    colab usage      # prints an OAuth URL → open in any browser → paste the code back"
say "Then, e.g.:"
say "    colab run --high-mem script.py    # fresh VM → run → fetch outputs → auto-teardown"
