#!/bin/bash

set -euo pipefail

export SONAR_USER_HOME="$PWD/.sonar"
sonar-scanner
