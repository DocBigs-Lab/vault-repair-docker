<p align="center">
  <a href="https://docbigs-lab.de">
    <img src="https://raw.githubusercontent.com/DocBigs-Lab/SML-Meter-Gateway/main/docs/assets/docbigslab_logo.svg" alt="DocBigsLab Logo" width="200">
  </a>
</p>
<p align="center">
  <a href="https://docbigs-lab.de">https://docbigs-lab.de</a>
</p>

**English** | [Deutsch](README.md)

# VAULT STL repair in a Docker container

Docker wrapper for [rawel2/vault-stl-repair](https://github.com/rawel2/vault-stl-repair) (MIT):
repairs the mesh errors of the **VAULT STL library** (USSA Design) in a single run —
on Linux (x86/arm64) and macOS with Docker Desktop, without Windows and without a Python setup on the host.

The `numpy` repair method removes duplicate face pairs, non-manifold edges and flipped
faces until slicers (Bambu Studio, OrcaSlicer) accept the files without complaint.

## What it repairs

- According to the upstream measurement (older library release with 310 faulty files), the
  numpy method fixes **308** of them (the S6-1F/2F locking module variants with walls stacked
  up to 12 times stay unchanged; only the upstream tool's Windows method handles those).
- Geometry is preserved (typical deviation 0 mm, never worse than the original —
  details and measurement tables in the upstream repo)
- Repaired files carry the STL header `VAULT STL repair (numpy)`

## Quick start

Requirements: Docker (with the Compose plugin), ~50 GB of free disk space during the run
(library ~24 GB, once as input and once as output).

```bash
# 1. Clone the repo
git clone https://github.com/DocBigs-Lab/vault-repair-docker.git vault-repair && cd vault-repair

# 2. Provide the VAULT library (folder containing 01. DRAWERS, 02. SUSTAINERS, …)
ln -s /path/to/VAULT ./vault

# 3. Create the target folder and set the host user (otherwise Docker creates the folder as root)
mkdir -p vault_repariert
printf 'HOST_UID=%s\nHOST_GID=%s\n' "$(id -u)" "$(id -g)" > .env

# 4. Build (~2 min, no internet needed afterwards)
docker compose build

# 5. Repair (with ~8 GB of RAM: --workers 1, see INSTALL.en.md)
docker compose run --rm vault-repair /vault /out --method numpy --workers 2
```

Repaired files end up in `./vault_repariert/`, together with a CSV report
(`vault_stl_repair.csv`: errors before/after per file).

## Usage

| Command | Purpose |
|---|---|
| `docker compose run --rm vault-repair /vault /out --method numpy` | whole library |
| `… --workers 4` | more cores in parallel (the largest modules need up to ~3.3 GiB of RAM **per worker**) |
| `… --only "S6"` | only files with "S6" in their path |
| `… --skip XL` | leave out the XL modules (the biggest chunks) |
| `… --all` | run error-free files through the repair as well |

**Interrupting is always fine:** the resume file `vault_stl_repair.json` lives in the target
folder, and the next `run` skips finished files. Ctrl+C, reboot, dead container: doesn't matter.

How many files have errors depends on the release of the library you received
(USSA ships fixes over time). Run time follows the **number of errors per file**,
not the file size: the two M5 modules, at 1,300–1,700 s each, took longer than all
43 other repaired files combined. Details and ways to speed things up
(`--skip XL`, `--workers`, resume restart) in [INSTALL.en.md](INSTALL.en.md).

## How it is built

Just a ~15-line `Dockerfile`: `python:3.12-slim` + `numpy` (pinned version), the two upstream
scripts copied in from a **fixed commit** and locked with a sha256 checksum, so the repair
tool does not drift with upstream. (The base image `python:3.12-slim` is a moving tag and
receives security updates.) `compose.yaml` mounts the source **read-only** and the target
folder read-write; the container runs as non-root with UID/GID from `.env` (default 1000:1000).

Installation details (UID, mount variants, troubleshooting):
see **[INSTALL.en.md](INSTALL.en.md)**.

## Limitations

- The two S6 modules (1F/2F) stay unrepaired — an upstream limit of the numpy method
- `--method windows` requires Windows and does **not** work in the container
- The STLs themselves are not part of this repo (© USSA Design, for backers/licensees only)
- This Docker wrapper is unofficial and not part of upstream; upstream authors: rawel2 + Claude

## License

MIT (wrapper code). Upstream tool: MIT (rawel2). VAULT design/STLs: © USSA Design.
