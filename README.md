# VAULT-STL-Reparatur im Docker-Container

Docker-Wrapper für [rawel2/vault-stl-repair](https://github.com/rawel2/vault-stl-repair) (MIT):
repariert die Mesh-Fehler der **VAULT-STL-Bibliothek** (USSA Design) komplett in einem Durchlauf —
plattformunabhängig auf Linux/arm64/x86, ohne Windows und ohne Python-Setup auf dem Host.

Die Reparatur-Methode `numpy` entfernt duplizierte Flächenpaare, nicht-manifold Kanten und
invertierte Flächen, bis Slicer (Bambu Studio, OrcaSlicer) die Dateien kampflos schlucken.

## Was es repariert

- 310 von 310 fehlerhaften Dateien in der Bibliothek — numpy-Methode: **308** (die
  S6-1F/2F-Schließmodul-Varianten mit bis zu 12-fach gestapelter Wand bleiben unverändert;
  dafür existiert nur die Windows-Methode des Upstream-Tools)
- Geometrie bleibt erhalten (typische Abweichung 0 mm, nie schlechter als das Original —
  Details und Messtabellen im Upstream-Repo)
- Reparierte Dateien tragen den STL-Header `VAULT STL repair (numpy)`

## Schnellstart

Voraussetzungen: Docker (mit Compose-Plugin), ~50 GB freier Speicher während des Laufs
(Bibliothek ~24 GB × Eingang + Ausgang).

```bash
# 1. Repo klonen
git clone https://github.com/DocBigs-Lab/vault-repair-docker.git vault-repair && cd vault-repair

# 2. VAULT-Bibliothek bereitstellen (Ordner mit 01. DRAWERS, 02. SUSTAINERS, …)
ln -s /pfad/zu/VAULT ./vault

# 3. Bauen (~2 min, danach kein Internet mehr nötig)
docker compose build

# 4. Reparieren (Arbeitsverzeichnisse entstehen von selbst)
docker compose run --rm vault-repair /vault /out --method numpy --workers 2
```

Fertige Dateien liegen in `./vault_repariert/`, mit CSV-Bericht
(`vault_stl_repair.csv`: Fehler vorher/nachher pro Datei).

## Bedienung

| Kommando | Zweck |
|---|---|
| `docker compose run --rm vault-repair /vault /out --method numpy` | komplette Bibliothek |
| `… --workers 4` | mehr Kerne parallel (größte Module brauchen einige GB RAM **pro Worker**) |
| `… --only "S6"` | nur Dateien mit „S6“ im Pfad |
| `… --skip XL` | XL-Module auslassen (die größten Brocken) |
| `… --all` | auch fehlerfreie Dateien durch die Reparatur-Jagd schicken |

**Unterbrechen jederzeit ok:** Die Resume-Datei `vault_stl_repair.json` liegt im Zielordner —
nächster `run` überspringt fertige Dateien. Ctrl+C, Reboot, Container-Tod: alles egal.

## Tempo (Richtwerte)

| Host | Ganze Bibliothek (733 STL, 310 mit Fehlern) |
|---|---|
| Laptop Core Ultra 7 (2 Worker, Upstream-Messung) | ~2 h |
| dein docker-host (2 Worker, live gemessen 31.10.) | ETA nach den großen Fehlerhaften ~3–5 h; mit `--skip XL` und mehr Workern deutlich drunter |
| DGX Spark / arm64-KI-Box (4+ Worker) | grob unter 1 h (Erwartung, nicht Referenzwert) |

Die Restzeit-Anzeige springt am Anfang: Reparaturzeit hängt von der **Fehlerzahl**
pro Datei ab, nicht von der Dateigröße — Details und Tempo-Hebel (`--skip XL`,
`--workers`, Resume-Neustart) in [INSTALL.md](INSTALL.md).

## Aufbau

Nur ein ~12-Zeilen-`Dockerfile`: `python:3.12-slim` + `numpy`, die beiden Upstream-Skripte
als **fester Commit** (Pin im Dockerfile) einkopiert — reproducible Build, kein
`latest`-Drift. `compose.yaml` mountet die Quelle **read-only** und den Zielordner lesend-
schreibend; Container läuft als Nicht-Root (`user:` in compose.yaml an deinen Host-User
anpassen, Standard 1000:1000).

Details zur Installation (UID ermitteln, Mount-Varianten, Troubleshooting):
siehe **[INSTALL.md](INSTALL.md)**.

## Grenzen / Ehrlichkeiten

- Die zwei S6-Module (1F/2F) bleiben unbearbeitet — Upstream-Limit der numpy-Methode
- `--method windows` braucht Windows und funktioniert **nicht** im Container
- Die STLs selbst sind nicht Teil dieses Repos (© USSA Design, nur für Backer/Lizenznehmer)
- Diese Docker-Hülle ist inoffiziell, kein Upstream-Teil; Upstream-Autoren: rawel2 + Claude

## Lizenz

MIT (Wrapper-Code). Upstream-Tool: MIT (rawel2). VAULT-Design/STLs: © USSA Design.
