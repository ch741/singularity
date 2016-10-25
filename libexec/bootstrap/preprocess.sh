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

if [ -z "${SINGULARITY_ROOTFS:-}" ]; then
    message ERROR "Singularity root file system not defined\n"
    exit 1
fi

message 1 "Bootstrap initialization\n"

if [ -z "${LC_ALL:-}" ]; then
    LC_ALL=C
fi
if [ -z "${LANG:-}" ]; then
    LANG=C
fi
if [ -z "${TERM:-}" ]; then
    TERM=xterm
fi
DEBIAN_FRONTEND=noninteractive
export LC_ALL LANG TERM DEBIAN_FRONTEND

if [ -n "$1" ]; then
    SINGULARITY_BUILDDEF="$1"
    if [ -n "$2" ]; then
        SINGULARITY_TMPDEF="$2"
    else
        message ERROR "Temporary definition not passed\n"
        exit 1
    fi
else
    message ERROR "Build definition not passed\n"
    exit 1
fi

if [ -n "${SINGULARITY_BUILDDEF:-}" ]; then
    message 1 "Preprocessing bootstrap definition\n";
    if [ -f "$SINGULARITY_BUILDDEF" ]; then
        if [ -n "${SINGULARITY_TMPDEF:-}" ]; then
            if [ -f "$SINGULARITY_TMPDEF" ]; then
                message 1 "Temporary definition file found: $SINGULARITY_TMPDEF\n"
            else
                message ERROR "Temporary definition file not found: $SINGULARITY_TMPDEF\n"
                exit 1
            fi
        else
            message ERROR "No temporary definition passed\n"
            exit 1
        fi
        # Check for inherit command, if there is and the files are valid preprocess that first.
        INHERITDEFS=`singularity_keys_get "Inherit" "$SINGULARITY_BUILDDEF"`
        if [ -n "$INHERITDEFS" ]; then
            for DEF in $INHERITDEFS; do
                if [[ $SINGULARITY_INHERITLIST == *"$DEF"* ]]; then
                    message ERROR "Cyclic inheritance detected. $DEF is already part of the inheritance tree.\n"
                    exit 1
                fi
                if [ -f $DEF ]; then
                    eval "$SINGULARITY_libexecdir/singularity/bootstrap/preprocess.sh" "$DEF" "$SINGULARITY_TMPDEF"
                else
                    message ERROR "Inherited Definition file not found: $DEF\n"
                    exit 1
                fi
            done
        fi
        # Retrieve all fields from temporary definition file
        SINGULARITY_TMPBOOTSTRAP=`singularity_key_get "BootStrap" "$SINGULARITY_TMPDEF"`
        TMPOSVERSION=`singularity_key_get "OSVersion" "$SINGULARITY_TMPDEF"`
        TMPMIRROR=`singularity_key_get "MirrorURL" "$SINGULARITY_TMPDEF"`
        TMPUPDATEURL=`singularity_key_get "UpdateURL" "$SINGULARITY_TMPDEF"`
        TMPINCLUDES=`singularity_keys_get "Include" "$SINGULARITY_TMPDEF"`
        TMPSETUP=`singularity_section_get "setup" "$SINGULARITY_TMPDEF"`
        TMPRUN=`singularity_section_get "runscript" "$SINGULARITY_TMPDEF"`
        TMPPOST=`singularity_section_get "post" "$SINGULARITY_TMPDEF"`
        TMPTEST=`singularity_section_get "test" "$SINGULARITY_TMPDEF"`
        
        # BootStrap system and OS version are only used from the child definition if they
        # don't exist already
        if ! [ -n "$SINGULARITY_TMPBOOTSTRAP" ]; then
            SINGULARITY_BOOTSTRAP=`singularity_key_get "BootStrap" "$SINGULARITY_BUILDDEF"`
        else
            SINGULARITY_BOOTSTRAP="$SINGULARITY_TMPBOOTSTRAP"
        fi

        if ! [ -n "$TMPOSVERSION" ]; then
            OSVERSION=`singularity_key_get "OSVersion" "$SINGULARITY_BUILDDEF"`
        else
            OSVERSION="$TMPOSVERSION"
        fi

        MIRROR=`singularity_key_get "MirrorURL" "$SINGULARITY_BUILDDEF"`
        if ! [ -n "$MIRROR" ]; then
            if [ -n "$TMPMIRROR" ]; then
                MIRROR="$TMPMIRROR"
            fi
        fi
        UPDATEURL=`singularity_key_get "UpdateURL" "$SINGULARITY_BUILDDEF"`
        if ! [ -n "$UPDATEURL" ]; then
            if [ -n "$TMPUPDATEURL" ]; then
                UPDATEURL="$TMPUPDATEURL"
            fi
        fi
        INCLUDES=`singularity_key_get "Include" "$SINGULARITY_BUILDDEF"`
        INCLUDES="$TMPINCLUDES $INCLUDES"

        SETUP=`singularity_section_get "setup" "$SINGULARITY_BUILDDEF"`
        RUN=`singularity_section_get "runscript" "$SINGULARITY_BUILDDEF"`
        POST=`singularity_section_get "post" "$SINGULARITY_BUILDDEF"`
        TEST=`singularity_section_get "test" "$SINGULARITY_BUILDDEF"`
        SETUP="$TMPSETUP\n$SETUP"
        RUN="$TMPRUN\n$RUN"
        POST="$TMPPOST\n$POST"
        TEST="$TMPTEST\n$TEST"
        > $SINGULARITY_TMPDEF
        echo "BootStrap: $SINGULARITY_BOOTSTRAP" >> $SINGULARITY_TMPDEF
        echo "OSVersion: $OSVERSION" >> $SINGULARITY_TMPDEF
        echo "MirrorURL: $MIRROR" >> $SINGULARITY_TMPDEF
        echo "UpdateURL: $UPDATEURL" >> $SINGULARITY_TMPDEF
        echo "Include: $INCLUDES" >> $SINGULARITY_TMPDEF
        echo -e "%runscript" >> $SINGULARITY_TMPDEF
        echo -e "$RUN" >> $SINGULARITY_TMPDEF
        echo "%post" >> $SINGULARITY_TMPDEF
        echo -e "$POST" >> $SINGULARITY_TMPDEF
    else
        message ERROR "Build Definition file not found: $SINGULARITY_BUILDDEF\n"
        exit 1
    fi
else
    message 1 "No bootstrap definition passed, updating container\n"
fi

message 1 "Done preprocessing $SINGULARITY_BUILDDEF\n"
exit 0
