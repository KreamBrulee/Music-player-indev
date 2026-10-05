# Contributing

Thanks for helping out! This is a small C++ project, so the loop is short.

## Setup
```bash
git clone https://github.com/<you>/Music-player-indev && cd Music-player-indev
git remote add upstream https://github.com/KreamBrulee/Music-player-indev
git checkout -b my-change origin/Nova_dev
cmake -B build -S . && cmake --build build -j
```

## Before you open a PR
```bash
ctest --test-dir build --output-on-failure   # unit tests
tests/smoke.sh                               # end-to-end API test (uses fake audio files)
cppcheck --enable=warning,performance,portability --error-exitcode=1 -q src/   # if installed
```
CI (`.github/workflows/ci.yml`) runs the same checks plus an image scan on every PR.

## Guidelines
- Keep changes focused; one topic per PR. Target the `Nova_dev` branch.
- New behaviour needs a test: pure logic → `tests/test_utils.cpp` (put it in a header under `src/` so it is testable); HTTP behaviour → a check in `tests/smoke.sh` and/or `api-tests/`.
- Don't commit music files, secrets or build output.
- Observability: new routes must be added to `normalizeRoute()` so metric labels stay bounded; log through `logEvent()`.
- Commit messages: short imperative subject (`Add /readyz endpoint`), details in the body.

## Where things are
`src/` server · `public/` UI · `tests/` unit + smoke · `api-tests/` Maven suite · `k8s/` manifests · `monitoring/` Prometheus/Grafana/ELK · `docs/` guides + SRE docs.
