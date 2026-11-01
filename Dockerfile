# syntax=docker/dockerfile:1.6
# STL-Reparatur für VAULT (numpy-Methode) — https://github.com/rawel2/vault-stl-repair (MIT)
# Pin: Commit 54c6b31f (2026-10-30, "numpy repair method"), Inhalt per sha256 festgenagelt
FROM python:3.12-slim
RUN pip install --no-cache-dir numpy==2.5.4
WORKDIR /app
# Skripte build-fest einkopieren (danach kein Netzwerk mehr nötig)
ADD --checksum=sha256:ff957b32b26f8c8e0d6f512ac2d168e519c410054f9930318aa9fbdd3acd1309 \
    https://raw.githubusercontent.com/rawel2/vault-stl-repair/54c6b31f7201eb6cac89669eee982b892de673ff/vault_stl_repair.py /app/
ADD --checksum=sha256:f5d052eac77ea28872ffb316376df344fd2750dcaef77185e8d336def6b065c9 \
    https://raw.githubusercontent.com/rawel2/vault-stl-repair/54c6b31f7201eb6cac89669eee982b892de673ff/numpy_repair.py /app/
RUN chmod 0644 /app/*.py  # ADD von URL liefert 0600/root -> lesbar für user
RUN python -m py_compile /app/*.py  # Syntax-Check beim Build
ENTRYPOINT ["python", "/app/vault_stl_repair.py"]
CMD ["--help"]
