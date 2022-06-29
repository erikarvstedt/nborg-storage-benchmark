# Commands useful for maintenance

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# Systemd journal
# Show messages messages with prio >= error since last boot
journalctl -b -p 3
journalctl -b -p 3 | egrep -v 'synapse|postfix|sshd'

# Show messages messages with prio >= warning since last boot
journalctl -b -p 4
journalctl -b -p 4 | egrep -v 'synapse|postfix|sshd' # exclude noisy services

journalctl -f

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# zfs
zpool status
zfs list
# show useful stats
zfs list -o space,used,compressratio -r rpool
zfs get compressratio

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# backups
# https://borgbackup.readthedocs.io/en/stable

journalctl -u borgbackup-job-main -n 50

# show repo stats
borg-job-main info
# list backups
borg-job-main list

## inspect backups
# show stats of last backup
borg-job-main info ::$(borg-job-main list --short | tail -1)
# show first 10 files of last backup
borg-job-main list ::$(borg-job-main list --short | tail -1) | head -10
# show specific paths
borg-job-main list ::$(borg-job-main list --short | tail -1) var/lib/clightning
# diff contents of penultimate backup with the last backup
backups=$(borg-job-main list --short); borg-job-main diff ::$(<<<"$backups" tail -2 | head -1) $(<<<"$backups" tail -1)

## restore files
# restore a path from last backup (dry-run)
borg-job-main extract --dry-run --progress --list ::$(borg-job-main list --short | tail -1) var/lib/clightning

# show specific file content from last backup
borg-job-main extract --stdout ::$(borg-job-main list --short | tail -1) var/lib/clightning/config
