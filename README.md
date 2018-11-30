# makeblastdb4cloud

This document describes how to create custom blast databases using Docker container.

## Sample command line

    docker run \
        -v /home/raytseli/google-key.json:/etc/google-key.json \
        -v /home/raytseli/t.prot:/tmp/t.prot \
        yraytselis/make-custom-db:v5 \
        make_custom_blastdb.sh \
        prot \
        /tmp/t.prot \
        gs://yan-customdb-test/d5 \
        aprot5 \
        "protein database 5"


### Explanation

`docker run`  -- invocation of the Docker container

`-v /home/raytseli/google-key.json:/etc/google-key.json`
    -- This parameter maps external to docker file, /home/raytseli/google-key.json, to the file /etc/google-key.json accessible in the docker container.
    The file must contain authentication credentials which allow the read/write access to the GCS bucket used to place custom blast databases.
    Note that the process running in the docker expects that credentials file will be found at /etc/google-key.json, so the external to docker file 
    must be mapped to this specific location.  If this parameter is not passed to docker, or the credentials in the file are invalid for read/write 
    access to GCS bucket, the process will fail unless the GCS bucket in question is publicly readable and writable 
    (see Google documentaion on setting GCS bucket permissions).

`-v /home/raytseli/t.prot:/tmp/t.prot`
    -- This parameter maps external to docker sequence file, /home/raytseli/t.prot, to the file /tmp/t.prot accessible in the docker container.
    The file must contain either sequence ids, one per line, or sequences in FASTA format. 

`yraytselis/make-custom-db:v5`
    -- This parameter is used to retrieve from docker hub the docker image used for creating docker container.

`make_custom_blastdb.sh`
    -- This parameter invokes the main driver script within docker container used for custom database creation.

`prot` -- sequence type, either prot or nucl.

`/tmp/t.prot` -- sequence file as specified by the file mapping above.

`gs://yan-customdb-test/d5`
    -- GCS bucket and directory where custom daatabase will be placed. 
    If only GCS bucket is specified, then the script will create a new directory in this bucket with the current timestamp as the name.

`aprot5` -- name of the custom database.

`"protein database 5"` -- optional database title. If title is not provided, it will be the same as the database name.
