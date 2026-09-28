#!/usr/bin/env bash
# MAME needs the validated SPC700 IPL; the shared driver calls require_bios.
exec "$(dirname "$0")/round8d-demo.sh" vawidth "$@"
