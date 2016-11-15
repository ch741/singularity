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
else
    message ERROR "Build definition not passed\n"
    exit 1
fi

if [ -n "${SINGULARITY_BUILDDEF:-}" ]; then
    message 1 "Preprocessing bootstrap definition\n";
    if [ -f "$SINGULARITY_BUILDDEF" ]; then
        INHERITLIST=`sed -n 's/^Inherit:\ *//p' $SINGULARITY_BUILDDEF`
        SINGULARITY_TMPDEF="${SINGULARITY_BUILDDEF}.tmp"
        cp $SINGULARITY_BUILDDEF $SINGULARITY_TMPDEF
        if [ -n "$INHERITLIST" ]; then
            INHERIT=
            for INHERIT in $INHERITLIST
            do
                if [[ $SINGULARITY_INHERITLIST == *"$INHERIT"* ]]; then
                    message ERROR "Cyclic inheritance detected. $INHERIT is already part of the inheritance tree.\n"
                    exit 1
                else
                    export SINGULARITY_INHERITLIST=$INHERIT:$SINGULARITY_INHERITLIST
                fi
                #TODO Verify URL and downloaded file
                unset URL
                URL=`echo $INHERIT | egrep '(https?|ftp)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'`
                if [ -n "$URL" ]; then
                    eval "curl -f -k -s -S -o remote.def" "$URL"
                    REMOTEDEF="remote.def"
                    if [ -f $REMOTEDEF ]; then
                        eval "$0" "$REMOTEDEF"
                    else
                        message ERROR "Remote definition failed to download"
                        exit 1
                    fi
                elif [ -f $INHERIT ]; then
                    eval "$0" "$INHERIT"
                else
                    message ERROR "Definition is not a valid URL or file."
                    exit 1
                fi
                awk -v awkin="$INHERIT" '$0 ~ awkin {
                   print $0
                   while((getline line<awkin )>0)
                       {print line}
                   next
                   }
                   {print}' $SINGULARITY_TMPDEF > tmp && \
                sed -i -e "s/^Inherit: $INHERIT//g" -e '/^#.*/d' tmp && \
                mv tmp $SINGULARITY_TMPDEF
            done
        fi

        # Check that multiple BootStrap and OSVersion keywords from definition file
        # are identical
        export SINGULARITY_BOOTSTRAP=`sed -n -e 's/BootStrap:\ //g' "$SINGULARITY_TMPDEF"|sort|uniq`
        if [ -n $SINGULARITY_BOOTSTRAP ]; then
            REPS=0
            for BOOTSTRAP in $SINGULARITY_BOOTSTRAP
            do
                REPS=$(($REPS+1))
                if [[ REPS -gt 1 ]]; then
                    message ERROR "Different BootStrap keywords detected. \
                        Make sure included definitions have matching BootStrap keywords\n"
                    exit 1
                elif [[ "$SINGULARITY_BOOTSTRAP" == "docker" ]]; then
                    message ERROR "Inheritance not supported with docker files.\n"
                    exit 1
                fi
            done
        else
            message ERROR "No BootStrap "
        fi

        OSVERSION=`sed -n -e 's/OSVersion:\ //g' "$SINGULARITY_TMPDEF"|sort|uniq`
        if [ -n $OSVERSION ]; then
            REPS=0
            for VERSION in $OSVERSION
            do
                REPS=$(($REPS+1))
                if [[ REPS -gt 1 ]]; then
                    message ERROR "Different OS versions detected. Make sure included definitions have matching OS versions\n"
                    exit 1
                fi
            done
        fi

        MIRROR=`awk '/Mirror: /&&c++ {next} 1' "$SINGULARITY_TMPDEF"`
        if ! [ -n "$MIRROR" ]; then
            message ERROR "No mirror URL present in definition."
        fi

        UPDATEURL=`sed -n -e 's/UpdateURL:\ //g' "$SINGULARITY_TMPDEF"|sort|uniq`
#        if [ -n "$UPDATEURL" ]; then
#        fi

        DUPPKGS=`sed -n -e 's/Include:\ //g' "$SINGULARITY_TMPDEF"|sort|uniq -d`
        for PKG in $DUPPKGS
        do
            message WARNING "Package $PKG is included multiple times"
        done
=======
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
        SINGULARITY_TMPBOOTSTRAP=`singularity_key_get "BootStrap" "$SINGULARITY_TMPDEF"`
        INHERITDEFS=`singularity_keys_get "Inherit" "$SINGULARITY_BUILDDEF"`
        if [ -n "$INHERITDEFS" ]; then
            if [[ "$SINGULARITY_TMPBOOTSTRAP" != "docker" ]]; then
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
            else
                message ERROR "Inheritance not supported with docker files.\n"
                exit 1
            fi
        fi
        # Retrieve all fields from temporary definition file
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
>>>>>>> cae0a0cb23e3ef922ceb76b4d2c590fb06207e75
    else
        message ERROR "Build Definition file not found: $SINGULARITY_BUILDDEF\n"
        exit 1
    fi
else
    message 1 "No bootstrap definition passed, updating container\n"
fi

message 1 "Done preprocessing $SINGULARITY_BUILDDEF\n"
exit 0
