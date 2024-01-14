#!/bin/sh

set -e

case "${#}/${1}" in
"0/") FORCE=false GIT_PUSH_OPT="" GIT_PUSH_TAG_OPT="" ;;
"1/--force") FORCE=true GIT_PUSH_OPT="--force-with-lease" GIT_PUSH_TAG_OPT="--force" ;;
*) echo "usage: ${0} [--force]"; exit 1 ;;
esac

ask_no_result() {
  echo "Cancelling release..."
  exit 1
}

ask() {
  printf "%s" "$2"
  read -r answer
  case "${answer}" in
  "") if test "$1" = "no" ; then ask_no_result ; fi ;;
  "Y"|"y"|"yes"|"Yes") ;;
  *) ask_no_result ;;
  esac
}

NAME=$(grep "^(name " dune-project | sed -Ee "s/^\(name (.*)\)/\1/")
VERSION=$(opam show -f version "./${NAME}.opam")
URL=$(opam show -f dev-repo "./${NAME}.opam" | sed -Ee 's/^"git\+(.*)"/\1/' | sed 's/\.git$//')

ask yes "Is the project called '${NAME}'? [Y/n] "
ask yes "Is the version '${VERSION}'? [Y/n] "
ask yes "Is the project url '${URL}'? [Y/n] "

printf "What do you want the tag to be named? "
read -r TAG

if git show "refs/tags/${TAG}" > /dev/null 2> /dev/null ; then
  if "${FORCE}" ; then
    git tag -d "${TAG}"
    dune-release tag "${TAG}"
  else
    ask no "[WARNING] This tag already exists. Do you want to skip the automatic tag creation? [y/N] "
  fi
else
  dune-release tag "${TAG}"
fi

ARCHIVE=${NAME}-${VERSION}.tar.gz
CHANGELOG=$(git tag -n99 "${TAG}" | tail -n +3 | sed "s/^ *//")
CURRENT_BRANCH=$(git branch --show-current)
SUBMODULES=$(git submodule)

WITH_SUBMODULES=no
if test -n "${SUBMODULES}" ; then
  printf "Git submodules detected. Do you want to include all the submodules? [y/n] "
  read -r answer

  case "${answer}" in
  "Y"|"y"|"yes"|"Yes") WITH_SUBMODULES=yes ;;
  "N"|"n"|"no"|"No") ;;
  *) ask_no_result ;;
  esac
fi

ARCHIVE_TMP_DIR=$(mktemp -d)
ARCHIVE_PREFIX="${NAME}-${VERSION}"
mkdir -p "${ARCHIVE_TMP_DIR}"

if test "${WITH_SUBMODULES}" = yes ; then
  # TODO: Add support for recursive submodules
  (
    export ARCHIVE_PREFIX
    export ARCHIVE_TMP_DIR

    # shellcheck disable=SC2016
    git submodule foreach 'git archive "${sha1}" --prefix "${ARCHIVE_PREFIX}/${sm_path}/" -o "${ARCHIVE_TMP_DIR}/${name}.tar.gz"'
  )
fi
git archive "${TAG}" --prefix "${ARCHIVE_PREFIX}/" -o "${ARCHIVE_TMP_DIR}/main.tar.gz"

(
  PREV_CWD=$(pwd)
  cd "${ARCHIVE_TMP_DIR}"

  for ar in ./* ; do
    tar xzf "${ar}"
  done

  tar czf "${PREV_CWD}/${ARCHIVE}" "${ARCHIVE_PREFIX}/"
)

(
  PREV_CWD=$(pwd)
  cd "${ARCHIVE_TMP_DIR}/${ARCHIVE_PREFIX}/"
  cp -r "${PREV_CWD}/.git" .
  dune-release check --working-tree
  opam lint
)

ask yes "Does that look alright? [Y/n] "

printf "Which branch do you want to push the new tag and current branch to? "
read -r REMOTE

git push ${GIT_PUSH_TAG_OPT} "${REMOTE}" "${TAG}"
git push ${GIT_PUSH_OPT} "${REMOTE}" "${CURRENT_BRANCH}"

if grep -q "^doc: " "${NAME}.opam"; then
  cp "${ARCHIVE}" "_build/"
  (
    cd _build/
    tar xzf "${ARCHIVE}"
    tar cjf "${NAME}-${VERSION}.tbz" "${NAME}-${VERSION}/"
  )
  dune-release publish doc
fi

echo
echo
echo

if "${FORCE}"; then
  echo "You can now update the release files at ${URL}/releases"
  echo "Here is the changelog to copy/past:"
  echo "${CHANGELOG}"
  echo
  echo "--------------------"
  echo "Then call opam publish again:"
  echo "opam publish \"${URL}/releases/download/${TAG}/${ARCHIVE}\""
else
  echo "Now please create a new release at ${URL}/releases/new?tag=${TAG}"
  echo "Here is the changelog to copy/past:"
  echo "${CHANGELOG}"
  echo
  echo "--------------------"
  echo "Please execute the follow command when you have created the release and uploaded the archive:"
  echo "opam publish \"${URL}/releases/download/${TAG}/${ARCHIVE}\""
fi
