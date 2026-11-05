#!/usr/bin/env bash
# Sobe o servidor local (a camera exige contexto seguro: localhost)
set -e
cd "$(dirname "$0")"
echo "==> http://localhost:8000  (Ctrl+C para parar)"
exec python3 -m http.server 8000
