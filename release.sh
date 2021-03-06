#!/bin/sh

set -e

case "${#}/${1}" in
"0/") FORCE=false GIT_OPT="" ;;
"1/--force") FORCE=true GIT_OPT="--force-with-lease" ;;
*) echo "usage: ${0} [--force]"; exit 1 ;;
esac

ask() {
  echo "$1"
  read answer
  case "${answer}" in
  "Y"|"y"|"yes"|"Yes"|"") ;;
  *) echo "Cancelling release..."; exit 1 ;;
  esac
}

NAME=$(grep "^(name " dune-project | sed -Ee "s/^\(name (.*)\)/\1/")
VERSION=$(grep "^(version " dune-project | sed -Ee "s/^\(version (.*)\)/\1/")
URL=$(grep "^dev-repo: " "${NAME}.opam" | sed -Ee "s/^dev-repo: \"git\+(.*)\.git\"/\1/")

dune-release tag

if git show-ref "refs/tags/${VERSION}" > /dev/null; then
  TAG=${VERSION}
elif git show-ref "refs/tags/v${VERSION}" > /dev/null; then
  TAG=v${VERSION}
else
  echo "Could not find a tag for the current latest version \"${VERSION}\""
  exit 1
fi

ARCHIVE=${NAME}-${VERSION}.tar.gz
CHANGELOG=$(git tag -n99 "${TAG}" | tail -n +3 | sed "s/^ *//")
CURRENT_BRANCH=$(git branch --show-current)

dune-release check
opam lint

ask "Does that look alright? [Y/n] "

# TODO: Add support for submodules
git archive "${TAG}" --prefix "${NAME}-${VERSION}/" -o "${ARCHIVE}"

ask "Is it ok to push the new tag and current branch to the remote \"origin\"? [Y/n] "

git push ${GIT_OPT} origin "${TAG}"
git push ${GIT_OPT} origin "${CURRENT_BRANCH}"

if grep -q "^doc: " "${NAME}.opam"; then
  cp "${ARCHIVE}" "_build/"
  dune-release publish doc
fi

if ${FORCE}; then
  echo "You can now update the release files at ${URL}/releases"
  echo "Then call opam publish again:"
  echo "opam publish \"${URL}/releases/download/${TAG}/${ARCHIVE}\""
else
  echo "Now please create a new release at ${URL}/releases/new"
  echo "Here is the changelog to copy/past:"
  echo "${CHANGELOG}"
  echo
  echo "--------------------"
  echo "Please execute the follow command when you have created the release and uploaded the archive:"
  echo "opam publish \"${URL}/releases/download/${TAG}/${ARCHIVE}\""
fi
