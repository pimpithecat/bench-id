#!/usr/bin/env bash
#
# 🇮🇩 Bench Indo Edition (v2025.11e)
# Author: pimpiTheCat
# Based on: Teddysun’s bench.sh (https://teddysun.com/444.html)
# Repository: https://github.com/pimpithecat/bench
#
# Description:
# Benchmark server fokus jaringan Indonesia & Asia.
# Menampilkan system info, disk I/O, dan Speedtest multi-node.
#

trap _exit INT QUIT TERM

# ---------- COLOR ----------
_red()    { printf '\033[0;31m%b\033[0m' "$1"; }
_green()  { printf '\033[0;32m%b\033[0m' "$1"; }
_yellow() { printf '\033[0;33m%b\033[0m' "$1"; }
_blue()   { printf '\033[0;36m%b\033[0m' "$1"; }

_exit() {
    _red "\nScript terminated. Cleaning up...\n"
    rm -rf speedtest-cli benchtest_* speedtest.tgz
    exit 1
}

_exists() { command -v "$1" >/dev/null 2>&1; }

next() { printf "%-70s\n" "-" | sed 's/\s/-/g'; }

# ---------- SYSTEM INFO ----------
get_system_info() {
    cname=$(awk -F: '/model name/{print $2;exit}' /proc/cpuinfo | sed 's/^[ \t]*//')
    cores=$(grep -c '^processor' /proc/cpuinfo)
    freq=$(awk -F: '/cpu MHz/{print $2;exit}' /proc/cpuinfo | sed 's/^[ \t]*//')
    ram=$(free -m | awk '/Mem/{print $2}')
    swap=$(free -m | awk '/Swap/{print $2}')
    disk=$(df -h / | awk 'NR==2 {print $2}')
    virt=$(systemd-detect-virt)
    os=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    kern=$(uname -r)
}

print_system_info() {
    echo " CPU Model          : $(_blue "$cname")"
    echo " CPU Cores          : $(_blue "$cores @ ${freq}MHz")"
    echo " Total RAM          : $(_blue "${ram} MB")"
    echo " Total Swap         : $(_blue "${swap} MB")"
    echo " Disk Size          : $(_blue "${disk}")"
    echo " OS                 : $(_blue "$os")"
    echo " Kernel             : $(_blue "$kern")"
    echo " Virtualization     : $(_blue "$virt")"
}

# ---------- DISK I/O ----------
io_test() {
    (LANG=C dd if=/dev/zero of=benchtest_$$ bs=512k count=2048 conv=fdatasync && rm -f benchtest_$$) 2>&1 |
    awk -F, '{io=$NF} END {print io}' | sed 's/^[ \t]*//;s/[ \t]*$//'
}

print_io() {
    io1=$(io_test)
    echo " I/O Speed(1st run) : $(_yellow "$io1")"
    io2=$(io_test)
    echo " I/O Speed(2nd run) : $(_yellow "$io2")"
    io3=$(io_test)
    echo " I/O Speed(3rd run) : $(_yellow "$io3")"
    avg=$(awk -v a="$io1" -v b="$io2" -v c="$io3" '
    function val(x){split(x,t," ");return (t[2]=="GB/s"?t[1]*1024:t[1])}
    BEGIN{printf "%.1f MB/s",(val(a)+val(b)+val(c))/3}')
    echo " I/O Average        : $(_green "$avg")"
}

# ---------- SPEEDTEST ----------
install_speedtest() {
    mkdir -p speedtest-cli
    arch=$(uname -m)
    case "$arch" in
        x86_64) sys="x86_64" ;;
        aarch64) sys="aarch64" ;;
        armv7l) sys="armhf" ;;
        *) _red "Unsupported arch: $arch\n"; exit 1 ;;
    esac
    url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${sys}.tgz"
    wget -qO speedtest.tgz "$url" || { _red "Failed to download Speedtest CLI\n"; exit 1; }
    tar -zxf speedtest.tgz -C speedtest-cli && chmod +x speedtest-cli/speedtest
    rm -f speedtest.tgz
}

# Jalankan Speedtest sampai berhasil, max 3 kali
run_node_test() {
    local id1="$1"
    local id2="$2"
    local name="$3"
    local attempt=0
    local result=""
    while [ $attempt -lt 3 ]; do
        result=$(./speedtest-cli/speedtest --progress=no --accept-license --accept-gdpr --server-id="$id1" 2>/dev/null)
        if echo "$result" | grep -q "Download"; then
            break
        fi
        result=$(./speedtest-cli/speedtest --progress=no --accept-license --accept-gdpr --server-id="$id2" 2>/dev/null)
        if echo "$result" | grep -q "Download"; then
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done

    dl=$(echo "$result" | awk '/Download/{print $3" "$4}')
    up=$(echo "$result" | awk '/Upload/{print $3" "$4}')
    lat=$(echo "$result" | awk '/Latency/{print $3" "$4}')

    # Kalau masih kosong, isi nilai dummy biar tabel rapi
    [ -z "$dl" ] && dl="0.00 Mbps"
    [ -z "$up" ] && up="0.00 Mbps"
    [ -z "$lat" ] && lat="999.99 ms"

    printf " %-22s %-15s %-15s %-10s\n" "$name" "$up" "$dl" "$lat"
}

run_speedtest() {
    COUNTRY=$(curl -s ipinfo.io/country)
    echo -e "\n $(_green "Network Speed Test (Asia Focus)")"
    printf " %-22s %-15s %-15s %-10s\n" "Node" "Upload" "Download" "Latency"
    next

    if [ "$COUNTRY" = "ID" ]; then
        run_node_test '15436' '18409' 'Jakarta'
        run_node_test '18201' '64184' 'Jakarta 2'
        run_node_test '4302'  '67752' 'Surabaya'
        run_node_test '40895' '42742' 'Medan'
        run_node_test '13623' '7556'  'Singapore'
        run_node_test '21569' '27377' 'Tokyo'
    else
        run_node_test '64184' '18201' 'Jakarta'
        run_node_test '13623' '7556'  'Singapore'
        run_node_test '21569' '27377' 'Tokyo'
    fi
}

# ---------- OUTPUT ----------
print_intro() {
    clear
    echo "──────────────────────────────────────────────────────────────"
    echo " 🌏 Bench Indo Edition (v2025.11e)"
    echo " Created by pimpiTheCat | Based on Teddysun's bench.sh"
    echo "──────────────────────────────────────────────────────────────"
}

print_end() {
    echo "──────────────────────────────────────────────────────────────"
    echo " Finished on $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "──────────────────────────────────────────────────────────────"
}

# ---------- MAIN ----------
main() {
    ! _exists "wget" && { _red "wget missing\n"; exit 1; }
    start=$(date +%s)
    print_intro
    next
    get_system_info
    print_system_info
    next
    print_io
    next
    install_speedtest
    run_speedtest
    rm -rf speedtest-cli
    next
    print_end
    end=$(date +%s)
    echo " Total Duration : $((end - start)) sec"
    echo
}

main "$@"
