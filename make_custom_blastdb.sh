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
##
## Create custom database and upload it to specified GCS bucket, or
## a subdirectory in the GCS bucket. The fuse.xml file needed by the remore-fuser
## will be generated based on the database files and uploaded to the same location.
##
##
## Usage:
## ./make_custom_blastdb.sh <nucl|prot> <input-seq-file> <gcs_bucket|gcs_bucket/dir> <database-name> [database-title]
##
##
## User notes:
##
## Note 1: account under which script executes must have read/write permissions in the GCS bucket. Script expects to find
##         account credentials in ${HOME}/google-key.json or /etc/google-key.json, in that order.
##
## Note 2: the make_fuse_xml.sh is expected to be in the $PATH or in the current working directory.
##
## Note 3: <input-seq-file> may contain either sequence identifiers, one per line, or sequences themselves, in FASTA format
##
## Note 4: GCS paramater may contain only GCS bucket (e.g. gs://my-bucket) or a bucket with directory (e.g. gs://my-bucket/my-dir).
##         In the first case, blast databases which script creates will be placed in a subdirectory which will have script execution
##         timestamp as its name, e.g. gs://my-bucket/2018-11-29-10-50-25.
##         In the second case, blast databases will be placed into bucket subdirectory as specified by the passed parameter. This way 
##         new databases can be incrementally added to GCS location already containing other blast databases. The fuse.xml file
##         created at the end of each execution of this script will always contain references to all database files, even after an
##         incremental update.
## 
##
## Developer notes:
##
## gcloud/gsutil package (Google Cloud SDK) must be installed.
## exit status: 0 on success, 1 on failure.
##


if [[ $# -lt 4 ]]; then
    echo 'usage: $0 <nucl|prot> <input-seq-file> <gcs_bucket|gcs_bucket/dir> <database-name> [database-title]'
    exit 1
fi

key_file=${HOME}/google-key.json
if [[ ! -f $key_file && ! -L $key_file ]]; then
    key_file=/etc/google-key.json
fi

gcloud auth activate-service-account --key-file $key_file

dbtype=$1

ezdb=protein
if [[ $dbtype == "nucl" ]]; then
    ezdb=nucleotide
fi

seq_file=$2

if [[ ! -f $seq_file && ! -L $seq_file ]]; then
    echo "input file $seq_file is not accessible"
    exit 1
fi

## create directory in which to generate database

target_dir=`date +"%Y-%m-%d-%H-%M-%S"`
mkdir $target_dir

if [[ $? -ne 0 ]]; then
    echo "can't create output subdirectory $target_dir"
    exit 1
fi

tmpfile=`mktemp`

## determine whether the input file constains seq ids or fasta sequences,
## if it is seq ids, then fetch fasta first

input_type=fasta

fasta=`grep -c '^>' $seq_file`

if [[ $fasta -eq 0 ]]; then
    while read seqid
    do
        efetch -db $ezdb -id $seqid -format asn >> $tmpfile
        if [[ $? -ne 0 ]]; then
            echo "efetch failed"
            exit 1
        fi
    done < $seq_file
    echo "Saving ASN.1 sequences to $tmpfile"

    seq_file=$tmpfile
    input_type=asn1_txt
fi

cd $target_dir

title=$4
if [[ $# -gt 4 ]]; then
    title=$5
fi

echo makeblastdb -in $seq_file -input_type $input_type -dbtype $dbtype -parse_seqids -out $4 -blastdb_version 5 -title \"$title\"
makeblastdb -in $seq_file -input_type $input_type -dbtype $dbtype -parse_seqids -out $4 -blastdb_version 5 -title "$title"

if [[ $? -ne 0 ]]; then
    echo "makeblastdb failed"
    rm $tmpfile
    exit 1
fi

rm $tmpfile
cd -

## if subdirectory is specified in the bucket, then use it, otherwise create a new subdirectory
has_subdir=`echo $3 | sed -e 's|gs://||' -e 's|/$||' |grep -c '/'`

gcs_dst=$3
if [[ $has_subdir -eq 0 ]]; then
    gcs_dst=$3/$target_dir
fi

## send database into GCS bucket
gsutil -o "GSUtil:parallel_process_count=8" -o "GSUtil:parallel_thread_count=1" -m rsync -J -P -R $target_dir $gcs_dst
if [[ $? -ne 0 ]]; then
    echo "database upload to GCS failed"
    exit 1
fi

## create fuse.xml

make_fuse_xml=make_fuse_xml.sh
which make_fuse_xml.sh >/dev/null 2>&1

if [[ $? -ne 0 ]]; then
    if [[ ! -x ./make_fuse_xml.sh ]]; then
        echo "make_fuse_xml.sh doesn't exist or not executable"
        exit 1
    else 
        make_fuse_xml=./make_fuse_xml.sh
    fi
fi

$make_fuse_xml $gcs_dst >$target_dir/fuse.xml
if [[ $? -ne 0 ]]; then
    echo "failed to create fuse.xml"
    exit 1
fi

gsutil cp $target_dir/fuse.xml $gcs_dst
if [[ $? -ne 0 ]]; then
    echo "failed to upload fuse.xml to GCS"
    exit 1
fi
