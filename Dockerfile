# STL-Reparatur für VAULT (numpy-Methode) — https://github.com/rawel2/vault-stl-repair (MIT)
# Pin: Commit 54c6b31f (2026-10-30, "numpy repair method")
FROM python:3.12-slim
RUN pip install --no-cache-dir numpy
WORKDIR /app
# Skripte build-fest einkopieren (danach kein Netzwerk mehr nötig)
ADD https://raw.githubusercontent.com/rawel2/vault-stl-repair/54c6b31f/vault_stl_repair.py /app/
ADD https://raw.githubusercontent.com/rawel2/vault-stl-repair/54c6b31f/numpy_repair.py /app/
RUN chmod 0644 /app/*.py  # ADD von URL liefert 0600/root -> lesbar für user
RUN head -c 40 /app/numpy_repair.py >/dev/null  # Datei-Check beim Build
ENTRYPOINT ["python", "/app/vault_stl_repair.py"]
CMD ["--help"]
