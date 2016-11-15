#!/bin/bash
# 
# Copyright (c) 2015-2016, Gregory M. Kurtzer. All rights reserved.
# 
# “Singularity” Copyright (c) 2016, The Regents of the University of California,
# through Lawrence Berkeley National Laboratory (subject to receipt of any
# required approvals from the U.S. Dept. of Energy).  All rights reserved.
# 
# This software is licensed under a customized 3-clause BSD license.  Please
# consult LICENSE file distributed with the sources of this project regarding
# your rights to use or distribute this software.
# 
# NOTICE.  This Software was developed under funding from the U.S. Department of
# Energy and the U.S. Government consequently retains certain rights. As such,
# the U.S. Government has been granted for itself and others acting on its
# behalf a paid-up, nonexclusive, irrevocable, worldwide license in the Software
# to reproduce, distribute copies to the public, prepare derivative works, and
# perform publicly and display publicly, and to permit other to do so. 
# 
# 


## Basic sanity
if [ -z "$SINGULARITY_libexecdir" ]; then
    echo "Could not identify the Singularity libexecdir."
    exit 1
fi

## Load functions
if [ -f "$SINGULARITY_libexecdir/singularity/functions" ]; then
    . "$SINGULARITY_libexecdir/singularity/functions"
else
    echo "Error loading functions: $SINGULARITY_libexecdir/singularity/functions"
    exit 1
fi

SINGULARITY_BUILDDEF="${1:-}"
shift
SINGULARITY_TMPDIR=`mktemp -d /tmp/singularity-bootstrap.XXXXXXX`

# Create a temporary definition file, if the definition inherits from other
# definitions all definitions are processed and collected into this.
SINGULARITY_TMPDEF="${SINGULARITY_BUILDDEF}.tmp"
# The inheritance list is used for avoiding cyclic inheritance.
SINGULARITY_INHERITLIST=$SINGULARITY_BUILDDEF
PATH=/bin:/sbin:$PATH
HOME=/root
RETVAL=0

export SINGULARITY_TMPDIR SINGULARITY_BUILDDEF 
export SINGULARITY_TMPDEF SINGULARITY_INHERITLIST

if [ -z "${SINGULARITY_BUILDDEF:-}" ]; then
    BOOTSTRAP_VERSION="2"
elif [ ! -f "${SINGULARITY_BUILDDEF:-}" ]; then
    message ERROR "Bootstrap defintion not found: ${SINGULARITY_BUILDDEF:-}\n"
elif grep -q "^DistType " "${SINGULARITY_BUILDDEF:-}"; then
    BOOTSTRAP_VERSION="1"
else
    BOOTSTRAP_VERSION="2"
fi

# At the moment preprocessing takes care of inheriting from other bootstrap definitions. 
if [[ "${BOOTSTRAP_VERSION}" == "2" ]]; then
    if [ -x "$SINGULARITY_libexecdir/singularity/bootstrap/preprocess.sh" ]; then
        eval "$SINGULARITY_libexecdir/singularity/bootstrap/preprocess.sh" "$SINGULARITY_BUILDDEF"
        if [[ "${RETVAL}" == "0" ]]; then
            export SINGULARITY_BUILDDEF="${SINGULARITY_BUILDDEF}.tmp"
        else
            message ERROR "Preprocessing failed."
            exit 1
        fi
    fi
fi

if [ -n "${BOOTSTRAP_VERSION:-}" ]; then
    if [ -x "$SINGULARITY_libexecdir/singularity/bootstrap/driver-v$BOOTSTRAP_VERSION.sh" ]; then
        eval "$SINGULARITY_libexecdir/singularity/bootstrap/driver-v$BOOTSTRAP_VERSION.sh" "$@"
        RETVAL=$?
    else
        echo "Could not locate version $BOOTSTRAP_VERSION bootstrap driver\n";
        exit 255
    fi
else
    message ERROR "Unrecognized bootstrap format of bootstrap definition\n"
fi

rm -rf "$SINGULARITY_TMPDIR"

exit $RETVAL
