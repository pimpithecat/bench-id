#!/usr/bin/env bash
#
# 🇮🇩 Bench Indo Edition (v2025.11g)
# Author: pimpiTheCat
# Inspired by Teddysun (https://teddysun.com/444.html)
# Repository: https://github.com/pimpithecat/bench
#
# Description:
# Benchmark server dengan fokus ke jaringan Indonesia & Asia.
# Menampilkan System Info, Disk I/O, dan Speedtest multi-node dengan stabilitas tinggi.
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
    ccache=$(awk -F: '/cache size/{print $2;exit}' /proc/cpuinfo | sed 's/^[ \t]*//')
    aes=$(grep -i 'aes' /proc/cpuinfo)
    virtflags=$(grep -Ei 'vmx|svm' /proc/cpuinfo)
    ram=$(free -m | awk '/Mem/{print $2}')
    usedram=$(free -m | awk '/Mem/{print $3}')
    swap=$(free -m | awk '/Swap/{print $2}')
    usedswap=$(free -m | awk '/Swap/{print $3}')
    uptime=$(awk '{a=$1/86400;b=($1%86400)/3600;c=($1%3600)/60} {printf("%d days, %d hrs, %d min\n",a,b,c)}' /proc/uptime)
    loadavg=$(awk '{print $1", "$2", "$3}' /proc/loadavg)
    os=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
    arch=$(uname -m)
    kern=$(uname -r)
    virt=$(systemd-detect-virt)
    disk_total=$(df -h / | awk 'NR==2 {print $2}')
    disk_used=$(df -h / | awk 'NR==2 {print $3}')
}

print_system_info() {
    echo " CPU Model          : $(_blue "$cname")"
    echo " CPU Cores          : $(_blue "$cores @ ${freq} MHz")"
    echo " CPU Cache          : $(_blue "$ccache")"
    [ -n "$aes" ] && echo " AES-NI             : $(_green "Enabled")" || echo " AES-NI             : $(_red "Disabled")"
    [ -n "$virtflags" ] && echo " VM-x/AMD-V         : $(_green "Enabled")" || echo " VM-x/AMD-V         : $(_red "Disabled")"
    echo " Total Disk         : $(_yellow "$disk_total") $(_blue "($disk_used Used)")"
    echo " Total RAM          : $(_yellow "${ram} MB") $(_blue "(${usedram} MB Used)")"
    echo " Total Swap         : $(_yellow "${swap} MB") $(_blue "(${usedswap} MB Used)")"
    echo " System Uptime      : $(_blue "$uptime")"
    echo " Load Average       : $(_blue "$loadavg")"
    echo " OS                 : $(_blue "$os")"
    echo " Arch               : $(_blue "$arch")"
    echo " Kernel             : $(_blue "$kern")"
    echo " Virtualization     : $(_blue "$virt")"
}

# ---------- DISK I/O ----------
io_test() {
    (LANG=C dd if=/dev/zero of=benchtest_$$ bs=512k count=2048 conv=fdatasync 2>&1) | awk -F, '{io=$NF} END {print io}' | sed 's/^[ \t]*//'
    rm -f benchtest_$$
}

print_io() {
    io1=$(io_test); echo " I/O Speed(1st run) : $(_yellow "$io1")"
    io2=$(io_test); echo " I/O Speed(2nd run) : $(_yellow "$io2")"
    io3=$(io_test); echo " I/O Speed(3rd run) : $(_yellow "$io3")"
    avg=$(awk -v a="$io1" -v b="$io2" -v c="$io3" '
        function val(x){split(x,t," ");return (t[2]=="GB/s"?t[1]*1024:t[1])}
        BEGIN{printf "%.1f MB/s",(val(a)+val(b)+val(c))/3}')
    echo " I/O Average        : $(_green "$avg")"
}

# ---------- SPEEDTEST ----------
install_speedtest() {
    [ -e "./speedtest-cli/speedtest" ] && return
    arch=$(uname -m)
    case "$arch" in
        x86_64) sys="x86_64" ;;
        aarch64) sys="aarch64" ;;
        armv7l) sys="armhf" ;;
        *) _red "Unsupported arch: $arch\n"; exit 1 ;;
    esac
    url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-${sys}.tgz"
    wget -qO speedtest.tgz "$url" || { _red "Download failed\n"; exit 1; }
    mkdir -p speedtest-cli && tar zxf speedtest.tgz -C ./speedtest-cli && chmod +x ./speedtest-cli/speedtest
    rm -f speedtest.tgz
}

speed_test() {
    local id="$1"
    local node="$2"
    local retries=3
    local success=0
    while [ $retries -gt 0 ]; do
        ./speedtest-cli/speedtest --progress=no --server-id="$id" --accept-license --accept-gdpr > ./speedtest-cli/log.txt 2>&1
        if grep -q "Download" ./speedtest-cli/log.txt; then
            success=1; break
        fi
        retries=$((retries - 1))
        sleep 3
    done

    if [ $success -eq 1 ]; then
        dl=$(awk '/Download/{print $3" "$4}' ./speedtest-cli/log.txt)
        up=$(awk '/Upload/{print $3" "$4}' ./speedtest-cli/log.txt)
        lat=$(awk '/Latency/{print $3" "$4}' ./speedtest-cli/log.txt)
    else
        dl="0.00 Mbps"; up="0.00 Mbps"; lat="999.00 ms"
    fi
    printf " %-18s %-14s %-14s %-10s\n" "$node" "$up" "$dl" "$lat"
}

run_speedtest() {
    echo
    echo " $(_green "Network Speed Test (Asia Focus)")"
    printf " %-18s %-14s %-14s %-10s\n" "Node" "Upload" "Download" "Latency"
    next
    speed_test '64184' "Jakarta"
    speed_test '18201' "Jakarta 2"
    speed_test '4302'  "Surabaya"
    speed_test '40895' "Medan"
    speed_test '13623' "Singapore"
    speed_test '21569' "Tokyo"
}

# ---------- OUTPUT ----------
print_intro() {
    clear
    echo "──────────────────────────────────────────────────────────────"
    echo " 🌏 Bench Indo Edition (v2025.11g)"
    echo " Created by pimpiTheCat"
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
