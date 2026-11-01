# Installationsanleitung

## Voraussetzungen

- Linux-Host mit Docker (Compose-Befehl: `docker compose` oder das ältere `docker-compose`-Plugin)
- Genug Speicher: die Bibliothek doppelt (Eingang ~24 GB + Ausgang ~24 GB)
- Die VAULT-STL-Bibliothek (gekauft bei [USSA Design](https://www.ussadesign.com/pages/vault);
  Ordner enthält `01. DRAWERS`, `02. SUSTAINERS`, …)

## Schritt 1 — Repo holen

```bash
cd /opt            # oder wo du es haben willst
git clone https://github.com/DocBigs-Lab/vault-repair-docker.git vault-repair
cd vault-repair
```

## Schritt 2 — Bibliothek einhängen

Variante A (empfohlen, kein Duplikat auf der Platte): Symlink auf den echten Ordner

```bash
ln -s /media/jens/VAULT ./vault
```

Variante B: echtes Bind-Mount-Ziel (wenn der Quellpfad anderswo liegt und du ihn nicht
verschieben willst) — trage in `compose.yaml` bei volumes einfach den absoluten Pfad ein:

```yaml
volumes:
  - /media/jens/VAULT:/vault:ro
  - ./vault_repariert:/out
```

Wichtig: Das Ziel (`/out`) darf **nicht** innerhalb der Quelle liegen (der Upstream-Test
weist sonst zurück, und der :ro-Mount würde ohnehin meckern).

## Schritt 3 — Benutzer anpassen

Der Container läuft per Default als `1000:1000`, damit die reparierten Dateien deinem
Host-User gehören und nicht root:

```bash
id -u && id -g          # UID:GID deines Users anzeigen
```

Bei anderen Werten in `compose.yaml` anpassen:

```yaml
user: "1000:1000"       # → deine Werte
```

(Genervte Root-Besitzer im Zielordner? `sudo chown -R <uid>:<gid> vault_repariert`.)

## Schritt 4 — Bauen

```bash
docker compose build
# older CLI: docker-compose build  /  docker compose build (Compose v2)
```

Der Build lädt die beiden Upstream-Skripte **einmalig vom gepinnten Commit** — der Stack
läuft danach ohne Internet. `python:3.12-slim` ist Multi-Arch: läuft auf x86-Servern und
ARM-Geräten (ARM-Board, Raspberry Pi 5, KI-Box).

## Schritt 5 — Erste Reparatur

```bash
docker compose run --rm vault-repair /vault /out --method numpy --workers 2
```

Erwartetes Bild:

```
Source: /vault
Target: /out
Method: numpy
STL files: 733, other files copied: 15
    repairing: M5 Module 4F.stl (3096738 Dreiecke, open 1, non-manifold 1249, flipped 2487)
[1/733] …: repaired (… -> open 0, non-manifold 0, flipped 0, 62 s)
    done 1, left 732 (4% der Daten), restlich etwa 0:25:58
```

Fortschritt ist Zeile pro Datei; Restzeit ist am Anfang hochgerechnet, weil die größten
Module zuerst laufen.

### Warum die Restzeit am Anfang springt

Die Reparaturzeit pro Datei hängt von der **Fehlerzahl** ab, nicht von der
Dreieckszahl: ein großer Modul mit 24 Defekten kann in unter einer Minute fertig
sein, ein kleinerer mit 7.500 Defekten 20 Minuten brauchen (die numpy-Reparatur
näht Schlitze, schließt Löcher und patcht verbleibende Knoten iterativ). Weil dazu
die fehlerfreien Kopier-Dateien (~3 s) die Prozent-Rechnung verwässern, ist das
ETA in den ersten Minuten ungenau — nach den ersten großen fehlerhaften Modulen
pendelt es sich ein.

Wer die XL-Module nicht druckt (Betten unter 340×320 mm, z. B. Snapmaker U1):
einfach `--skip XL` ergänzen — die XLs liegen quer bei 42,8° und sind die
Zeitmonster der Bibliothek.

Wer mehr Kerne frei hat: Abbrechen (Strg+C) und mit mehr Workern neu starten ist
jederzeit sicher — die Resume-Datei im Zielordner setzt fort, Fertiges wird
übersprungen. Richtwert: `worker ≈ min(Kerne/2, RAM_GB/6)`; bei hoher Worker-Zahl
`OMP_NUM_THREADS=2` setzen (compose.yaml → `environment:`), sonst streiten die
numpy-Threads der Worker untereinander um Kerne.

## Schritt 6 — Ergebnis prüfen

```bash
ls vault_repariert/                  # Spiegel der Bibliothek
grep -i "still has errors" vault_repariert/*.csv   # Dateien, die numpy nicht ganz sauber bekam
# Plausibilitäts-Check: wie viele Kopien meldet die CSV mit 0 Dreiecken?
awk -F, '$3==0 && $2=="copied"' vault_repariert/*.csv | wc -l
```

Bei „still has errors" gilt: die Erwartung hängt vom Stand deiner gelieferten
Bibliothek ab — im Extremfall (frische USSA-Lieferung) sind es null Dateien,
bei älterem Stand laut Upstream die zwei S6-Module (1F/2F), für die es aktuell
nur die Windows-Methode des Upstream-Tools gibt.

Der 0-Dreiecke-Check: Zeilen mit `copied` und 0 Dreiecken wurden ohne jeden
Scan durchgewinkt. Einzelne davon sind harmlos, aber wenn halbe Bibliotheken
so dastehen, prüf die Dateigrößen dieser Dateien (`ls -la`) — winzige Dateien
deuten auf eine unvollständige Lieferung, nicht auf ein Reparaturproblem.

## Troubleshooting

| Bild | Ursache & Lösung |
|---|---|
| `can't open file '/app/vault_stl_repair.py': Permission denied` | Dockerfile ohne `chmod 0644 /app/*.py` (Docker legt URL-`ADD`s als 0600/root ab). Aktualisieren oder selbst ergänzen, dann `docker compose build`. |
| `STL source folder not found` / leere Liste | Symlink zeigt ins Leere oder `01. DRAWERS` fehlt eine Ebene — `/vault` muss genau den Ordner mit `01. DRAWERS`, `02. …` enthalten |
| `target must not lie inside source` | `/out` aus der Quellen-Hierarchie raus-mounten |
| `Permission denied` beim Schreiben in `vault_repariert/` | `user:` in compose.yaml nicht dein Host-User (siehe Schritt 3) |
| RAM-Hunger / OOM-Killed | `--workers` runter (größte Module brauchen einige GB pro Worker) |
| Container tot während Lauf | Einfach `docker compose run …` erneut starten — Resume-Datei im Zielordner setzt fort |

## Deinstallation

```bash
docker compose down
docker rmi vault-repair-vault-repair   # oder deinen build-tag
rm -rf /opt/vault-repair
```

Es bleiben nur deine eigenen Verzeichnisse (`vault/`, `vault_repariert/`).
