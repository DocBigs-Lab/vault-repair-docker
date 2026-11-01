<p align="center">
  <a href="https://docbigs-lab.de">
    <img src="https://raw.githubusercontent.com/DocBigs-Lab/SML-Meter-Gateway/main/docs/assets/docbigslab_logo.svg" alt="DocBigsLab Logo" width="200">
  </a>
</p>
<p align="center">
  <a href="https://docbigs-lab.de">https://docbigs-lab.de</a>
</p>

# VAULT-STL-Reparatur im Docker-Container

Docker-Wrapper für [rawel2/vault-stl-repair](https://github.com/rawel2/vault-stl-repair) (MIT):
repariert die Mesh-Fehler der **VAULT-STL-Bibliothek** (USSA Design) komplett in einem Durchlauf —
plattformunabhängig auf Linux (x86/arm64) und macOS mit Docker Desktop, ohne Windows und ohne Python-Setup auf dem Host.

Die Reparatur-Methode `numpy` entfernt duplizierte Flächenpaare, nicht-manifold Kanten und
invertierte Flächen, bis Slicer (Bambu Studio, OrcaSlicer) die Dateien kampflos schlucken.

## Was es repariert

- Laut Upstream-Messung (älterer Bibliotheksstand mit 310 fehlerhaften Dateien) schafft die
  numpy-Methode **308** davon (die S6-1F/2F-Schließmodul-Varianten mit bis zu 12-fach
  gestapelter Wand bleiben unverändert; dafür existiert nur die Windows-Methode des
  Upstream-Tools).
- Geometrie bleibt erhalten (typische Abweichung 0 mm, nie schlechter als das Original —
  Details und Messtabellen im Upstream-Repo)
- Reparierte Dateien tragen den STL-Header `VAULT STL repair (numpy)`

## Schnellstart

Voraussetzungen: Docker (mit Compose-Plugin), ~50 GB freier Speicher während des Laufs
(Bibliothek ~24 GB, einmal als Eingang und einmal als Ausgang).

```bash
# 1. Repo klonen
git clone https://github.com/DocBigs-Lab/vault-repair-docker.git vault-repair && cd vault-repair

# 2. VAULT-Bibliothek bereitstellen (Ordner mit 01. DRAWERS, 02. SUSTAINERS, …)
ln -s /pfad/zu/VAULT ./vault

# 3. Zielordner und Host-User festlegen (sonst legt Docker den Ordner als root an)
mkdir -p vault_repariert
printf 'HOST_UID=%s\nHOST_GID=%s\n' "$(id -u)" "$(id -g)" > .env

# 4. Bauen (~2 min, danach kein Internet mehr nötig)
docker compose build

# 5. Reparieren
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

Wie viele Dateien Fehler haben, hängt vom Stand deiner gelieferten Bibliothek ab
(USSA liefert nach und nach fixes nach) — die Laufzeit folgt der **Fehlerzahl pro
Datei**, nicht der Dateigröße: die zwei M5-Module mit je 1.300–1.700 s waren
langsamer als alle anderen 43 reparierten zusammen. Details und Tempo-Hebel
(`--skip XL`, `--workers`, Resume-Neustart) in [INSTALL.md](INSTALL.md).

## Aufbau

Nur ein ~15-Zeilen-`Dockerfile`: `python:3.12-slim` + `numpy` (Version gepinnt), die beiden
Upstream-Skripte als **fester Commit** einkopiert und per sha256-Prüfsumme festgenagelt —
das Reparatur-Tool driftet nicht mit Upstream mit. (Das Basis-Image `python:3.12-slim` ist
ein wandernder Tag und bekommt Sicherheits-Updates.) `compose.yaml` mountet die Quelle
**read-only** und den Zielordner lesend-schreibend; Container läuft als Nicht-Root mit
UID/GID aus `.env` (Standard 1000:1000).

Details zur Installation (UID ermitteln, Mount-Varianten, Troubleshooting):
siehe **[INSTALL.md](INSTALL.md)**.

## Grenzen / Ehrlichkeiten

- Die zwei S6-Module (1F/2F) bleiben unbearbeitet — Upstream-Limit der numpy-Methode
- `--method windows` braucht Windows und funktioniert **nicht** im Container
- Die STLs selbst sind nicht Teil dieses Repos (© USSA Design, nur für Backer/Lizenznehmer)
- Diese Docker-Hülle ist inoffiziell, kein Upstream-Teil; Upstream-Autoren: rawel2 + Claude

## Lizenz

MIT (Wrapper-Code). Upstream-Tool: MIT (rawel2). VAULT-Design/STLs: © USSA Design.
