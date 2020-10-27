#!/bin/bash -e
#
# Copyright 2017 The rkt Authors
# Copyright 2020 Kinvolk
#
# Attempt to bump the Lokomotive release to the specified version by replacing all
# occurrences of the current/previous version.
#
# Generates two commits: the release itself and the bump to the next +git
# version

# make sure we are running in a toplevel directory
if ! [[ "$0" =~ "scripts/bump-release" ]]; then
    echo "This script must be run in a toplevel Lokomotive directory"
    exit 255
fi

if ! [[ "$1" =~ ^v[[:digit:]]+.[[:digit:]]+.[[:digit:]]$ ]]; then
    echo "Usage: scripts/bump-release <VERSION>"
    echo "   where VERSION must be vX.Y.Z"
    exit 255
fi

function replace_stuff() {
    local FROM
    local TO
    local REPLACE

    FROM=$1
    TO=$2
    # escape special characters
    REPLACE=$(sed -e 's/[]\/$*.^|[]/\\&/g'<<< $FROM)
    shift 2
    echo $* | xargs sed -i --follow-symlinks -e "s/$REPLACE/$TO/g"
}

function replace_version() {
    replace_stuff $1 $2 pkg/version/version.go
}

NEXT=${1:1}             # 0.2.3
NEXTGIT="${NEXT}+git"   # 0.2.3+git

PREVGIT=$(grep 'var Version = ' pkg/version/version.go | cut -d"=" -f2 | sed 's/ //g;s/"//g') # 0.1.2+git
PREV=${PREVGIT::-4}     # 0.1.2

replace_version $PREVGIT $NEXT
git commit -asm "version: bump to v${NEXT}"

replace_version $NEXT $NEXTGIT
git commit -asm "version: bump to v${NEXTGIT}"
