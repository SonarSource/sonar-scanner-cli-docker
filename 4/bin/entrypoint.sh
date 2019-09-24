#!/bin/bash

set -e
set -o pipefail

export SONAR_USER_HOME="$PWD/.sonar"
sonar-scanner
