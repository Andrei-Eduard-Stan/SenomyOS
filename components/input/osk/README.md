# SenomyOS wvkbd resize extension

This patch extends the current trial provider, not a permanent provider decision.
Upstream: https://github.com/jjsullivan5196/wvkbd at
bbecd996aae5a4dc4bc32bd643d37cefa9f63752 (0.21). Source hashes are in upstream.json.
The modified keyboard source/extension follows upstream GPLv3; retain upstream
COPYING, LICENSE and MIT notices when packaging the resulting binary.

Build without installing or starting anything:

    python3 scripts/build-osk-resize.py PINNED_UPSTREAM_DIRECTORY OUTPUT_BINARY

The helper verifies the three modified upstream files, builds in a private copy
and preserves the caller's upstream source. Build dependencies are a C compiler,
make, pkg-config, wayland-scanner, Wayland client, xkbcommon and pangocairo. No
network download, sudo, service restart or automatic package installation.
This is a repeatable pinned-source build, not a bit-identical artifact claim.

--senomy-resize enables top/side/corner pointer and touch handles and emits only
bounded geometry JSON. No key text is emitted. The managed launch opts into this
extension only when the bounded executable read finds its feature markers, with
--no-popup to avoid old popup positioning during layout changes. Ordinary upstream
providers keep their original fixed argv.

A transparent full-work-area surface has an input region restricted to the
keyboard rectangle. Only an active edge drag expands its input region so a fast
pointer can cross the former edge without losing the gesture. Release, cancel,
leave and hide restore the region. Drawing buffers are reused during dragging;
geometry changes update every key layout and the bottom exclusive zone, without
restarting the process. Minimum sizes adapt to smaller outputs; maximum height
is 60 percent of the discovered work area. Session dimensions survive hide/show.

The compositor reserves a rectangular bottom strip even for a narrowed keyboard.
Tiled applications resize above it; their contents and floating/fullscreen apps
remain controlled by those applications. Native physical touch, rotation,
fractional scale and multi-output acceptance remain open. Full-size transparent
buffers have an output/scale-dependent memory cost; broader resource acceptance
is still required before selecting this as a permanent mobile provider.
