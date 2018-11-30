#!/bin/bash

# ===========================================================================
#
#                            PUBLIC DOMAIN NOTICE
#               National Center for Biotechnology Information
#
#  This software/database is a "United States Government Work" under the
#  terms of the United States Copyright Act.  It was written as part of
#  the author's offical duties as a United States Government employee and
#  thus cannot be copyrighted.  This software/database is freely available
#  to the public for use. The National Library of Medicine and the U.S. 
#  Government have not placed any restriction on its use or reproduction.
#
#  Although all reasonable efforts have been taken to ensure the accuracy
#  and reliability of the software and data, the NLM and the U.S. 
#  Government do not and cannot warrant the performance or results that 
#  may be obtained by using this software or data. The NLM and the U.S. 
#  Government disclaim all warranties, express or implied, including
#  warranties of performance, merchantability or fitness for any particular
#  purpose.
#
#  Please cite the author in any work or product based on this material.
#
# ===========================================================================

## Purpose:
## Create fuse.xml file needed by remote-fuser to access files in the specified GCS bucket, or 
## a subdirectory in the GCS bucket.
##
## Usage:
## ./make_fuse_xml.sh <gcs_bucket/dir>
##
## Developer notes:
## gsutil package must be installed, and read access to the GCS bucket granted.
## exit status: 0 on success, 1 on failure.
##

if [[ $# -lt 1 ]]; then
    echo "usage: $0 <gcs_bucket/dir>"
    exit 0
fi
# check that latest-dir exists
err=`gsutil ls -d $1`

if [[ $? -ne 0 ]]; then
    echo "Can't process $1"
    exit 1
fi

gcs_files=(`gsutil ls -lR $1 | sed -e '/^$/d' -e '/^gs:/d' -e '/^ *gs:/d' -e '/TOTAL:/d' -e 's/ /;/g'`)
dirpath=`echo $1 | sed -e 's/gs:\/\///' -e 's/\/$//'`
version=`basename $dirpath`

echo '<?xml version="1.0" encoding="UTF-8"?>'
echo '<FUSE version="'$version'" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
echo '      xsi:noNamespaceSchemaLocation="../../schemas/sra-fuser.v2.xsd">'

for file_info in "${gcs_files[@]}"
do
    info=(`echo $file_info | sed 's/;/ /g'`)
    fname=`echo ${info[2]} | sed -e "s|$1||" -e 's|^/||'`
    base_fname=`basename $fname`
    if [[ $base_fname != fuse.xml ]]; then
        tstamp=`echo ${info[1]} | sed 's/Z$//'`
        echo '	<File name="'$base_fname'"	size="'${info[0]}'"	path="https://storage.googleapis.com/'$dirpath'/'$fname'"	timestamp="'$tstamp'"/>'
    fi
done

echo '</FUSE>'
