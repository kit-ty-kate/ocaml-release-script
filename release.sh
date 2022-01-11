#!/bin/sh

set -e

NAME=$(grep "^(name " dune-project | sed -Ee "s/^\(name (.*)\)/\1/")
VERSION=$(grep "^(version " dune-project | sed -Ee "s/^\(version (.*)\)/\1/")
URL=$(grep "^dev-repo: " "${NAME}.opam" | sed -Ee "s/^dev-repo: \"git\+(.*)\.git\"/\1/")

TAG=v${VERSION}
ARCHIVE=${NAME}-${VERSION}.tbz
CHANGELOG=$(git tag -n99 "${TAG}" | tail -n +3)

dune-release tag
dune-release check
opam lint

echo "Does that look alright? [Y/n] "
read answer
case "${answer}" in
"Y"|"y"|"yes"|"Yes"|"") ;;
*) echo "Cancelling release..."; exit 1;;
esac

git archive "${TAG}" --prefix "${NAME}-${VERSION}/" -o "${ARCHIVE}"

cp "${ARCHIVE}" "_build/"
dune-release publish doc

echo "Now please create a new release at ${URL}/releases/new"
echo "Here is the changelog to copy/past:"
echo "${CHANGELOG}"
echo
echo "--------------------"
echo "Please execute the follow command when you have created the release and uploaded the archive:"
echo "opam publish \"${URL}/releases/download/${TAG}/${ARCHIVE}\""
