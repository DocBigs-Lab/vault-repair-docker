[English](INSTALL.en.md) | **Deutsch**

# Installationsanleitung

## Voraussetzungen

- Docker mit Compose: Linux (x86/arm64) oder macOS mit Docker Desktop
  (Befehl `docker compose`, bei alten Installationen `docker-compose`)
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

## Schritt 3 — Zielordner und Benutzer

Den Zielordner **selbst anlegen**. Fehlt er, erzeugt Docker ihn beim Mount als `root`,
und der Container (Nicht-Root) kann dann nicht hineinschreiben:

```bash
mkdir -p vault_repariert
```

Der Container läuft als dein Host-User, damit die reparierten Dateien dir gehören und
nicht root. UID/GID kommen aus einer `.env` neben `compose.yaml` (ohne `.env` gilt `1000:1000`):

```bash
printf 'HOST_UID=%s\nHOST_GID=%s\n' "$(id -u)" "$(id -g)" > .env
```

(Zielordner gehört schon root? `sudo chown -R "$(id -u):$(id -g)" vault_repariert`.)

## Schritt 4 — Bauen

```bash
docker compose build    # alte Installationen: docker-compose build
```

Der Build lädt die beiden Upstream-Skripte **einmalig vom gepinnten Commit** und prüft
ihre sha256-Prüfsummen — der Stack läuft danach ohne Internet. `ADD --checksum` braucht
BuildKit (bei aktuellem Docker Standard). `python:3.12-slim` ist Multi-Arch: läuft auf x86-Servern und
ARM-Geräten (ARM-Board, Raspberry Pi 5, KI-Box).

## Schritt 5 — Erste Reparatur

```bash
docker compose run --rm vault-repair /vault /out --method numpy --workers 2
```

Erwartetes Bild (gekürzt, das Upstream-Tool gibt Englisch aus):

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

Fortschritt ist Zeile pro Datei; Restzeit ist am Anfang hochgerechnet, weil die größten
Module zuerst laufen.

### Warum die Restzeit am Anfang springt

Die Reparaturzeit pro Datei hängt von der **Fehlerzahl** ab, nicht von der
Dreieckszahl: ein großes Modul mit wenigen Defekten ist in wenigen Minuten fertig
(XL5² mit 20 Defekten: 86 s, XL4² mit 105 Defekten: 609 s), ein kleineres mit 7.500
Defekten kann 20 Minuten brauchen (die numpy-Reparatur näht Schlitze, schließt
Löcher und patcht verbleibende Knoten iterativ). Weil dazu die fehlerfreien
Kopier-Dateien (~3 s) die Prozent-Rechnung verwässern, ist das ETA in den ersten
Minuten ungenau — nach den ersten großen fehlerhaften Modulen pendelt es sich ein.

Messwerte kompletter Läufe:

| Bibliotheksstand | Fehlerdateien | Host | Dauer |
|---|---|---|---|
| neuer (733 STL) | 45 | 2 Worker | 31:27 (zwei M5-Module ~80 % davon) |
| älter (723 STL) | 305 (303 repariert) | 1 Worker, 8 GB RAM mit weiteren Diensten, 4 GB Swap | 3:01:25 |

Wer die XL-Module nicht druckt (Betten unter 340×320 mm, z. B. Snapmaker U1):
einfach `--skip XL` ergänzen — die XLs liegen quer bei 42,8° und sind die
Zeitmonster der Bibliothek.

Wer mehr Kerne frei hat: Abbrechen (Strg+C) und mit mehr Workern neu starten ist
jederzeit sicher — die Resume-Datei im Zielordner setzt fort, Fertiges wird
übersprungen. Bei hoher Worker-Zahl `OMP_NUM_THREADS=2` setzen (compose.yaml →
`environment:`), sonst streiten die numpy-Threads der Worker untereinander um Kerne.

### RAM: was wirklich frei ist, zählt

Ein Worker braucht am XL5²-Modul in der Spitze **3,3 GiB** (gemessen). Maßgeblich ist
nicht der gesamte RAM, sondern was neben deinen anderen Diensten frei ist:

```bash
free -h    # Spalte "available"
```

Richtwert: `worker ≈ min(Kerne/2, available_GiB/3,5)`. Liegt „available“ unter
~3,5 GiB, reicht selbst ein Worker nicht, und der Kernel beendet den Prozess (siehe
Troubleshooting). Dann hilft eine Swap-Datei; die Spitze ist kurz, der Lauf wird nur
etwas langsamer:

```bash
sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab   # dauerhaft
```

(`fallocate` gilt für ext4; auf btrfs braucht eine Swap-Datei andere Schritte.)
Mit wenig freiem RAM bei **einem** Worker bleiben, auch nach den XL-Modulen — ein
zweiter Worker würde nur in den Swap ausweichen.

### Lange Läufe über SSH

Ein kompletter Lauf kann Stunden dauern. Bricht die SSH-Verbindung ab, beendet das den
Container **nicht**: er läuft im Hintergrund weiter und wird wegen des abgebrochenen
Clients auch nicht per `--rm` aufgeräumt. Startet man dann einen zweiten Lauf, schreiben
beide in denselben Zielordner und überschreiben gegenseitig die Resume-Datei.

Deshalb lange Läufe in `tmux` starten (Befehle einzeln eingeben):

```bash
tmux new -s vault
```
```bash
cd /opt/vault-repair && docker compose run --rm vault-repair /vault /out --method numpy --workers 1; echo "Exit-Code: $?"
```

Abkoppeln mit Strg+B, dann D; wieder verbinden mit `tmux attach -t vault`.
Vor jedem Neustart prüfen, dass kein alter Lauf mehr aktiv ist:

```bash
docker ps --filter name=vault-repair    # muss leer sein
```

Läuft dort noch einer: `docker stop <ID> && docker rm <ID>`. Hat er parallel zu einem
anderen Lauf geschrieben, den Zielordner leeren und sauber neu starten.

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
| `Permission denied` beim Schreiben in `vault_repariert/` | Ordner wurde von Docker als root angelegt oder `.env` passt nicht zu deinem User (siehe Schritt 3) |
| `unknown flag: --checksum` o. ä. beim Build | Altes Docker ohne BuildKit — Docker aktualisieren oder `DOCKER_BUILDKIT=1 docker compose build` |
| `BrokenProcessPool: A process in the process pool was terminated abruptly` | Ein Worker wurde vom OOM-Killer des Kernels beendet (`sudo dmesg -T \| grep -i oom`). Die größten Module laufen zuerst, deshalb passiert das meist gleich am Anfang. Mit `--workers 1` neu starten; wenn die XL-Module durch sind und `free -h` genug „available“ zeigt, abbrechen und mit mehr Workern fortsetzen. |
| Lauf endet ohne Fehlermeldung (mit `--workers 1`), Exit-Code 137 | Ebenfalls OOM-Killer: bei einem Worker rechnet der Hauptprozess selbst und wird ohne Traceback beendet. `free -h` prüfen, bei unter ~3,5 GiB „available“ Swap einrichten (siehe „RAM: was wirklich frei ist, zählt“) |
| RAM-Hunger / OOM-Killed | `--workers` runter (größte Module brauchen bis zu 3,3 GiB pro Worker), sonst Swap |
| Container tot während Lauf | Einfach `docker compose run …` erneut starten — Resume-Datei im Zielordner setzt fort |
| SSH-Verbindung abgebrochen | Container läuft weiter. `docker ps --filter name=vault-repair` prüfen und **keinen** zweiten Lauf starten, solange er aktiv ist (siehe „Lange Läufe über SSH“) |

## Deinstallation

Achtung: `vault_repariert/` liegt im Repo-Ordner und wäre mit weg. Erst die
reparierten Dateien in Sicherheit bringen, dann löschen:

```bash
mv /opt/vault-repair/vault_repariert ~/VAULT_repariert   # Ziel nach Wahl
docker rmi vault-repair
rm -rf /opt/vault-repair
```

Die Original-Bibliothek bleibt unberührt: `vault` ist nur ein Symlink, `rm -rf`
löscht den Link, nicht das Ziel.
