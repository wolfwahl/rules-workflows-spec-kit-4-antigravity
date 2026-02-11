#!/usr/bin/env bash
set -euo pipefail

./scripts/verify_flutter_env.sh

./scripts/flutterw.sh pub get
./scripts/flutterw.sh analyze
./scripts/flutterw.sh test
