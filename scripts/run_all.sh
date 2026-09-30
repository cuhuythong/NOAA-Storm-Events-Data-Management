#!/usr/bin/env bash
set -euo pipefail
Rscript scripts/build_database.R
Rscript scripts/make_figures.R
