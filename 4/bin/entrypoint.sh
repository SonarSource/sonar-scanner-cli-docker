#!/bin/bash

args=()

for ENV_NAME in $(compgen -e); do
    SONAR_CHECK=${ENV_NAME%%_*}
    if [ "$SONAR_CHECK" == "SONAR" ]; then
      NAME=${ENV_NAME#*_}
      NAME=`echo $NAME | sed -e 's/__/./'` | sed -e 's/\(.*\)/\L\1/' | sed -e 's/\(_[a-z]\)/\U\1/' | sed -e 's/_//'`
      args+=("-Dsonar.$NAME=${!ENV_NAME}")
    fi

    if [ "$ENV_NAME" == "DEBUG_SONAR" ]; then
      args+=("-X")
    fi
done

sonar-scanner "${args[@]}"
