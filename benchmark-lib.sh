resetPostgresql() {(
    set -euo pipefail
    systemctl stop postgresql
    rm -rf /var/lib/postgresql/*
    systemctl start postgresql
)}

postgresqlCmds() {
    systemctl status postgresql
    systemctl restart postgresql
    systemctl stop postgresql
    journalctl -u postgresql -n 200

    ls -al /var/lib/postgresql
    findmnt /var/lib/postgresql
    zfs get all rpool/root/db
    zfs get used rpool/root/db
    zfs get logicalused rpool/root/db

    # real disk usage
    du -sh /var/lib/db
    # uncompressed (logical) size
    du -sh --apparent-size /var/lib/db

    sudo -u postgres psql -l
    echo 'DROP DATABASE "matrix-synapse";' | sudo -u postgres psql
}

dbDatasetExists() {
    zfs get type rpool/root/db &>/dev/null
}

createDbDataset() {
    if ! dbDatasetExists; then
        zfs create -o mountpoint=legacy -o canmount=on "$@" rpool/root/db
    fi
}

destroyDbDataset() {
    if dbDatasetExists; then
        zfs destroy rpool/root/db
    fi
}

disableDbMount() {(
    set -euo pipefail
    if [[ ! $(findmnt /var/lib/db) ]]; then
        echo "db mount is already disabled"
        return
    fi
    set -x
    systemctl stop postgresql
    umount /var/lib/postgresql
    umount /var/lib/db
)}

enableDbZfs() {(
    set -euo pipefail
    if [[ $(findmnt /var/lib/db) ]]; then
        echo "db mount is already enabled"
        return
    fi
    set -x
    mount -t zfs -o x-mount.mkdir rpool/root/db /var/lib/db
    systemctl stop postgresql
    mkdir -p /var/lib/db/postgresql /var/lib/postgresql
    chown postgres: /var/lib/db/postgresql /var/lib/postgresql
    mount --bind /var/lib/db/postgresql /var/lib/postgresql
)}

enableDbBtrfs() {(
    set -euo pipefail
    if [[ $(findmnt /var/lib/db) ]]; then
        echo "db mount is already enabled"
        return
    fi
    set -x
    mount -t btrfs -o compress=zstd /dev/disk/by-label/btrfs /var/lib/db
    systemctl stop postgresql
    mkdir -p /var/lib/db/postgresql /var/lib/postgresql
    chown postgres: /var/lib/db/postgresql /var/lib/postgresql
    mount --bind /var/lib/db/postgresql /var/lib/postgresql
)}

enableDbExt4() {(
    set -euo pipefail
    if [[ $(findmnt /var/lib/db) ]]; then
        echo "db mount is already enabled"
        return
    fi
    set -x
    mount /dev/disk/by-label/ext4 /var/lib/db
    systemctl stop postgresql
    mkdir -p /var/lib/db/postgresql /var/lib/postgresql
    chown postgres: /var/lib/db/postgresql /var/lib/postgresql
    mount --bind /var/lib/db/postgresql /var/lib/postgresql
)}

deploySystem() {(
  set -euxo pipefail
  system=$1
  nix build ./deployment#packages.x86_64-linux.$system --out-link /tmp/deploy-nborg-benchmark/system
  nix copy --to ssh://nborg-benchmark /tmp/deploy-nborg-benchmark/system
  ssh -n nborg-benchmark "$(realpath /tmp/deploy-nborg-benchmark/system)/bin/switch-to-configuration switch"
)}

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# benchmarks

run_pgbench() {(
    set -euxo pipefail
    resetPostgresql
    # Create the benchmark database with the same command as the matrix-synapse database
    echo 'CREATE DATABASE "bench" WITH OWNER "matrix-synapse" TEMPLATE template0 LC_COLLATE = "C" LC_CTYPE = "C";' | sudo -u postgres psql
    # for scale=N, N*16MiB of data are created
    time sudo -u postgres pgbench --initialize --scale=50 bench
    # warmup (1 sec.)
    sudo -u postgres pgbench --client=10 --jobs=2 --time=1 bench >/dev/null
    durationMinutes=3
    time sudo -u postgres pgbench --client=10 --jobs=2 --time=$((60*durationMinutes)) bench
)}

pgbench_zfs() {(
    set -euo pipefail
    disableDbMount
    destroyDbDataset
    createDbDataset "$@"
    enableDbZfs
    run_pgbench
)}

pgbench_btrfs() {(
    set -euo pipefail
    disableDbMount
    destroyDbDataset
    enableDbBtrfs
    run_pgbench
)}


pgbench_btrfs_mirror_compression_zstd() {(
    disableDbMount
    # data: mirror, metadata: mirror
    mkfs.btrfs -f -d raid1 -m raid1 -L btrfs /dev/sda4 /dev/sdb4
    pgbench_btrfs
)}

pgbench_btrfs_striped_compression_zstd() {(
    disableDbMount
    # data: striped, metadata: mirror
    mkfs.btrfs -f -d raid0 -m raid1 -L btrfs /dev/sda4 /dev/sdb4
    pgbench_btrfs
)}

pgbench_ext4() {(
    set -euo pipefail
    disableDbMount
    destroyDbDataset
    enableDbExt4
    run_pgbench
)}

run_db_import_benchmark() {(
    set -euxo pipefail
    resetPostgresql
    importSizeMiB=500
    importSizeBytes=$(( ((2**10)**2)*importSizeMiB ))
    time </root/tmp/restore/matrix-synapse.sql.gz head -c $importSizeBytes | pv -s $importSizeBytes | zcat | sudo -u postgres psql
)}

db_import_benchmark_with_params() {(
    set -euo pipefail
    disableDbMount
    destroyDbDataset
    createDbDataset "$@"
    enableDbZfs
    run_db_import_benchmark
)}

run_all_benchmarks() {(
    set -euxo pipefail

    pgbench_zfs

    pgbench_zfs \
        -o recordsize=8K

    pgbench_zfs \
        -o primarycache=metadata

    pgbench_zfs \
        -o logbias=throughput

    pgbench_zfs \
        -o recordsize=8K \
        -o primarycache=metadata \
        -o logbias=throughput

    pgbench_btrfs_mirror_compression_zstd

    pgbench_btrfs_striped_compression_zstd

    disableDbMount
    mkfs.ext4 -F -L ext4 /dev/sda5
    # work around bug "mount: /var/lib/db: special device /dev/disk/by-label/ext4 does not exist"
    sleep 0.5
    pgbench_ext4

    disableDbMount
)}
