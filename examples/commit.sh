#!/bin/bash

export LC_ALL=C.UTF-8

AUTHOR="${1}"
AUTHOR="${AUTHOR//\"/}"
EMAIL="${2}"
EMAIL="${EMAIL//\"/}"

# Дата в формате YYYY-MM-DD hh:mm:ss
GIT_COMMITTER_DATE="${3}"
GIT_COMMITTER_DATE="${GIT_COMMITTER_DATE//\"/}.000000000 +0300"

export GIT_COMMITTER_NAME="${AUTHOR}"
export GIT_COMMITTER_EMAIL="${EMAIL}"
export GIT_COMMITTER_DATE
MESSAGE="${4}"
MESSAGE="${MESSAGE//\"/}"

REPO_ROOT_PATH="$(pwd)"

cd "${REPO_ROOT_PATH}" || exit 1

git commit --date="${GIT_COMMITTER_DATE}" --author="${AUTHOR} <${EMAIL}>" -m "${MESSAGE}"
