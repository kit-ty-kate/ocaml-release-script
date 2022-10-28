#!/bin/sh

set -e

case "${#}/${1}" in
"0/") FORCE=false GIT_OPT="" ;;
"1/--force") FORCE=true GIT_OPT="--force-with-lease" ;;
*) echo "usage: ${0} [--force]"; exit 1 ;;
esac

ask() {
  echo -n "$1"
  read answer
  case "${answer}" in
  "Y"|"y"|"yes"|"Yes"|"") ;;
  *) echo "Cancelling release..."; exit 1 ;;
  esac
}

NAME=$(grep "^(name " dune-project | sed -Ee "s/^\(name (.*)\)/\1/")
VERSION=$(opam show -f version "./${NAME}.opam")
URL=$(opam show -f dev-repo "./${NAME}.opam" | sed -Ee 's/^"git\+(.*)"/\1/' | sed 's/\.git$//')

ask "Is the project called '${NAME}'? [Y/n] "
ask "Is the version '${VERSION}'? [Y/n] "
ask "Is the project url '${URL}'? [Y/n] "

echo -n "What do you want the tag to be named? "
read TAG

dune-release tag "${TAG}"

ARCHIVE=${NAME}-${VERSION}.tar.gz
CHANGELOG=$(git tag -n99 "${TAG}" | tail -n +3 | sed "s/^ *//")
CURRENT_BRANCH=$(git branch --show-current)

dune-release check
opam lint

ask "Does that look alright? [Y/n] "

# TODO: Add support for submodules
git archive "${TAG}" --prefix "${NAME}-${VERSION}/" -o "${ARCHIVE}"

echo -n "Which branch do you want to push the new tag and current branch to? "
read REMOTE

git push ${GIT_OPT} "${REMOTE}" "${TAG}"
git push ${GIT_OPT} "${REMOTE}" "${CURRENT_BRANCH}"

if grep -q "^doc: " "${NAME}.opam"; then
  cp "${ARCHIVE}" "_build/"
  (
    cd _build/
    tar xzf "${ARCHIVE}"
    tar cjf "${NAME}-${VERSION}.tbz" "${NAME}-${VERSION}/"
  )
  dune-release publish doc
fi

if ${FORCE}; then
  echo "You can now update the release files at ${URL}/releases"
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
