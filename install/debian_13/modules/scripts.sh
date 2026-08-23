#!/bin/bash

set -e

log 'Copying shell functions...'

ensure_folder "$PROJECT_ROOT/scripts"

cp "$SH_ROOT"/scripts/* "$PROJECT_ROOT/scripts/"
