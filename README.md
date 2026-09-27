# colab-cli-termux-native

Run **Google's official [Colab CLI](https://github.com/googlecolab/google-colab-cli)** (`colab`) natively on Termux (aarch64) — no proot, no root. Provision remote CPU / GPU / TPU runtimes, run a local script on them, pull the outputs back, and tear the VM down — all driven from your phone.

The compute is all remote on Colab's VMs, so this turns an Android device into a terminal for a fleet of ephemeral cloud accelerators. Handy as an **unattended, power-outage-proof compile/GPU host** — kick off a long job (`colab run` supports background execution up to ~24h on Colab Pro/Pro+), close the terminal, collect the artifact later.

## Requirements

- Termux (aarch64).
- A Google account. Colab Pro/Pro+ if you want high-RAM machine shapes (`--high-mem`) or long background jobs.
- ~200 MB for the glibc Python venv (the CLI + its wheels).

## Install

```bash
git clone https://github.com/Thr45hx/colab-cli-termux-native
cd colab-cli-termux-native
bash install.sh
```

Or one-shot:

```bash
curl -fsSL https://raw.githubusercontent.com/Thr45hx/colab-cli-termux-native/main/install.sh | bash
```

Then, one time:

```bash
colab usage      # prints a Google OAuth URL → open in any browser → paste the code back
```

## How it works

The Colab CLI is a **thin, pure-Python client** — there is no binary to patchelf (unlike a Go/Rust/Node CLI). The catch is two of its **compiled dependencies**:

| Dependency | Why native Termux Python fails |
| --- | --- |
| `cryptography` (via google-auth) | its `_rust.abi3.so` can't resolve `PyExc_Warning` against Termux's bionic Python ABI |
| `pyarrow` (via jupyter-kernel-client → jupyter-mimetypes) | no Termux wheel; the Apache Arrow C++ source build fails |

The fix is to run the whole CLI on the Termux **glibc Python 3.12** (`python-glibc`, invoked through `grun`/`glibc-runner`). There, `cryptography`, `pyarrow`, and `pydantic-core` all install as **prebuilt manylinux aarch64 wheels** — zero source builds.

| Piece | What it is |
| --- | --- |
| **glibc venv** (`~/.local/share/colab-cli-termux/venv`) | `google-colab-cli` + deps on the glibc Python 3.12 |
| **`libsqlite-glibc`** | the CLI's `filelock.ReadWriteLock` is sqlite-backed; the glibc `_sqlite3` needs `libsqlite3.so.0`. Without it, `filelock.ReadWriteLock` is silently `None` and every real command dies with `TypeError: 'NoneType' object is not callable` |
| **`colab` launcher** (`$PREFIX/bin/colab`) | a tiny wrapper: `exec grun "$VENV/bin/python" "$VENV/bin/colab" "$@"` |

## Usage

```bash
colab usage                          # compute-unit balance
colab new [--gpu T4|L4|A100] [--high-mem]   # allocate a runtime
colab run [--high-mem] script.py [args...]  # fresh VM → run → fetch outputs → auto-teardown
colab exec -f notebook.ipynb         # run code/notebook on an active session
colab upload local remote / colab download remote local
colab ssh                            # shell into the runtime over WebSocket
colab stop                           # release a runtime
```

See `colab <command> --help` for the full surface.

## Uninstall

```bash
bash uninstall.sh
```

Removes the launcher and venv. The shared glibc runtime (`glibc-runner`, `python-glibc`, `libsqlite-glibc`) is left in place because other native Termux tools use it.

## Notes

- **Auth** is a one-time out-of-band OAuth (open URL, paste code) — no localhost redirect, so it works fine over SSH/headless. Uses Application Default Credentials by default; `--auth oauth2` is available.
- **Cost:** the CLI is free; Colab compute is metered in Compute Units. Colab Pro is a flat, capped subscription — it can't run away with your card the way a left-running cloud VM can. Check `colab usage` / `colab pay`.
- Part of a family of native-Termux CLI ports (Claude Code, OpenCode, Grok, Copilot, gcloud, …) that share the same glibc-runner recipe.

## License

MIT — see [LICENSE](./LICENSE).
