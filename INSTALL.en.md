**English** | [Deutsch](INSTALL.md)

# Installation guide

## Requirements

- Docker with Compose: Linux (x86/arm64) or macOS with Docker Desktop
  (command `docker compose`, on old installations `docker-compose`)
- Enough disk space: the library twice (input ~24 GB + output ~24 GB)
- The VAULT STL library (purchased from [USSA Design](https://www.ussadesign.com/pages/vault);
  the folder contains `01. DRAWERS`, `02. SUSTAINERS`, …)

## Step 1 — Get the repo

```bash
cd /opt            # or wherever you want it
git clone https://github.com/DocBigs-Lab/vault-repair-docker.git vault-repair
cd vault-repair
```

## Step 2 — Mount the library

Option A (recommended, no duplicate on disk): a symlink to the real folder

```bash
ln -s /media/jens/VAULT ./vault
```

Option B: a direct bind mount (if the source lives elsewhere and you don't want to
move it) — put the absolute path into the volumes section of `compose.yaml`:

```yaml
volumes:
  - /media/jens/VAULT:/vault:ro
  - ./vault_repariert:/out
```

Important: the target (`/out`) must **not** lie inside the source (the upstream check
rejects it, and the :ro mount would refuse anyway).

## Step 3 — Target folder and user

**Create the target folder yourself.** If it is missing, Docker creates it as `root` when
mounting, and the (non-root) container cannot write into it:

```bash
mkdir -p vault_repariert
```

The container runs as your host user so that the repaired files belong to you, not root.
UID/GID come from a `.env` next to `compose.yaml` (without `.env`, `1000:1000` is used):

```bash
printf 'HOST_UID=%s\nHOST_GID=%s\n' "$(id -u)" "$(id -g)" > .env
```

(Target folder already owned by root? `sudo chown -R "$(id -u):$(id -g)" vault_repariert`.)

## Step 4 — Build

```bash
docker compose build    # old installations: docker-compose build
```

The build downloads the two upstream scripts **once from the pinned commit** and verifies
their sha256 checksums — afterwards the stack runs without internet. `ADD --checksum` needs
BuildKit (the default in current Docker). `python:3.12-slim` is multi-arch: it runs on x86
servers and ARM devices (ARM boards, Raspberry Pi 5, AI boxes).

## Step 5 — First repair

```bash
docker compose run --rm vault-repair /vault /out --method numpy --workers 2
```

Expected output (abridged):

```
Source: /vault
Target: /out
Method: numpy
STL files: 733, other files copied: 15
To do: 733 (already done: 0)
    repairing: M5 Module 4F.stl (3096738 triangles, open 1, non-manifold 1249, flipped 2487)
[1/733] …: repaired (… -> open 0, non-manifold 0, flipped 0, …, 62 s)
    done 1, left 732 (4% of data), elapsed 0:01:02, remaining about 0:25:58
```

Progress is one line per file; the remaining time is extrapolated at the start because the
largest modules run first.

### Why the remaining time jumps at the start

The repair time per file depends on the **number of errors**, not the triangle count:
a large module with 24 defects can be done in under a minute, a smaller one with 7,500
defects can take 20 minutes (the numpy repair stitches slits, closes holes and patches
remaining knots iteratively). On top of that, the error-free files that are just copied
(~3 s) dilute the percentage calculation, so the ETA is inaccurate for the first few
minutes and settles after the first large faulty modules. Measured: a full run (733 STL,
45 of them faulty, 2 workers) took 31:27, with two M5 modules eating about 80 % of that.

If you don't print the XL modules (beds smaller than 340×320 mm, e.g. Snapmaker U1):
just add `--skip XL` — the XLs lie diagonally at 42.8° and are the time hogs of the library.

If you have more cores to spare: aborting (Ctrl+C) and restarting with more workers is
always safe — the resume file in the target folder continues, finished files are skipped.
Rule of thumb: `workers ≈ min(cores/2, RAM_GB/6)`, so only 1 worker with 8 GB of RAM
(measured: peak 3.3 GiB for one worker on the XL5² module, see troubleshooting
`BrokenProcessPool`); with many workers, set
`OMP_NUM_THREADS=2` (compose.yaml → `environment:`), otherwise the workers' numpy threads
compete for cores.

## Step 6 — Check the result

```bash
ls vault_repariert/                  # mirror of the library
grep -i "still has errors" vault_repariert/*.csv   # files numpy could not fully clean
# Sanity check: how many copies does the CSV report with 0 triangles?
awk -F, '$3==0 && $2=="copied"' vault_repariert/*.csv | wc -l
```

For "still has errors", the expectation depends on the release of your library: in the
best case (fresh USSA delivery) there are none, with older releases, according to upstream,
the two S6 modules (1F/2F), which currently only the upstream tool's Windows method handles.

The zero-triangle check: rows with `copied` and 0 triangles were passed through without any
scan. A few of them are harmless, but if half the library looks like that, check the sizes
of those files (`ls -la`) — tiny files point to an incomplete delivery, not a repair problem.

## Troubleshooting

| Symptom | Cause & fix |
|---|---|
| `can't open file '/app/vault_stl_repair.py': Permission denied` | Dockerfile without `chmod 0644 /app/*.py` (Docker stores URL `ADD`s as 0600/root). Update or add it yourself, then `docker compose build`. |
| `STL source folder not found` / empty list | Symlink points nowhere or `01. DRAWERS` is one level off — `/vault` must be exactly the folder containing `01. DRAWERS`, `02. …` |
| `target must not lie inside source` | Mount `/out` outside the source hierarchy |
| `Permission denied` when writing to `vault_repariert/` | Folder was created by Docker as root, or `.env` doesn't match your user (see step 3) |
| `unknown flag: --checksum` or similar during build | Old Docker without BuildKit — update Docker or use `DOCKER_BUILDKIT=1 docker compose build` |
| `BrokenProcessPool: A process in the process pool was terminated abruptly` | A worker was killed by the kernel's OOM killer (`sudo dmesg -T \| grep -i oom`). The largest modules run first, so this usually happens right at the start. Restart with `--workers 1`; once the XL modules are done, abort and continue with more workers. |
| High RAM usage / OOM-killed | Lower `--workers` (the largest modules need several GB per worker) |
| Container died during the run | Just run `docker compose run …` again — the resume file in the target folder continues |

## Uninstall

Careful: `vault_repariert/` lives inside the repo folder and would be deleted too. Move the
repaired files somewhere safe first, then delete:

```bash
mv /opt/vault-repair/vault_repariert ~/VAULT_repariert   # destination of your choice
docker rmi vault-repair
rm -rf /opt/vault-repair
```

The original library stays untouched: `vault` is only a symlink, `rm -rf` removes the
link, not its target.
