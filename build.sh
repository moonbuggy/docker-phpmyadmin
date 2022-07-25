#! /bin/bash
# shellcheck disable=SC2034

#NOOP='true'
#DO_PUSH='true'
#NO_BUILD='true'

DOCKER_REPO="${DOCKER_REPO:-moonbuggy2000/phpmyadmin}"

all_tags='latest english'
default_tag='latest'

. "hooks/.build.sh"
