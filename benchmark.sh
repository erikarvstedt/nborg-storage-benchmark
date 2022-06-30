# Run Step 1 in ./deployment/deploy.sh (kexec into the installer system)
# Rename nixbitcoin.org -> nborg-benchmark in ~/.ssh/config

# Test login
ssh nborg-benchmark :

<./benchmark-format-storage.sh ssh nborg-benchmark 'bash -s'

source ./benchmark-lib.sh

run_benchmark() {(
    set -euo pipefail
    name=$1
    deploySystem $name
    { nix eval --raw ./deployment#$name.description; echo; } > $name-results
    <./benchmark-lib.sh ssh nborg-benchmark 'source <(cat) && run_all_benchmarks' |& tee -a $name-results
)}

run_benchmark benchmark1
run_benchmark benchmark2
run_benchmark benchmark3

./format_results.rb ./benchmark*-results > results.htm

#―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
# helper
ssh nborg-benchmark 'systemctl start postgresql'
ssh nborg-benchmark 'systemctl stop postgresql'
ssh nborg-benchmark 'ls -al /var/lib/postgresql/'
ssh nborg-benchmark 'cat /var/lib/postgresql/*/postgresql.conf'
ssh nborg-benchmark 'ps uaxwwf'
ssh nborg-benchmark 'free -h'
ssh nborg-benchmark -O exit
