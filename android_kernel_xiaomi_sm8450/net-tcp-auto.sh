#!/system/bin/sh
# TCP Auto-switch
# Wi-Fi -> BBRv2 (safe gain)
# Mobile -> Westwood
# Requires root

LOG_TAG="net-tcp-auto"
SLEEP_INTERVAL=15

# Ensure running as root
[ "$(id -u)" != "0" ] && echo "Need root" && exit 1

set_algorithm() {
    ALGO=$1
    IFACE=$2

    if [ "$ALGO" = "bbr2" ]; then
        sysctl -w net.ipv4.tcp_congestion_control=bbr2
        sysctl -w net.ipv4.tcp_bbr2_pacing_gain=1.5
        sysctl -w net.ipv4.tcp_bbr2_cwnd_gain=1.5
        sysctl -w net.ipv4.tcp_bbr2_drain_gain=1.0
        tc qdisc replace dev $IFACE root fq
        log -t $LOG_TAG "Switched $IFACE -> BBRv2"
    elif [ "$ALGO" = "westwood" ]; then
        sysctl -w net.ipv4.tcp_congestion_control=westwood
        tc qdisc replace dev $IFACE root fq_codel
        log -t $LOG_TAG "Switched $IFACE -> Westwood"
    fi
}

get_interfaces() {
    WIFI_IF=$(ip link | grep -E "wlan|wl" | awk -F: '{print $2}' | tr -d ' ')
    MOBILE_IF=$(ip link | grep -E "rmnet|ccmni|usb" | awk -F: '{print $2}' | tr -d ' ')
}

CURRENT_ALGO_WIFI=""
CURRENT_ALGO_MOBILE=""

while true; do
    get_interfaces
    [ -z "$WIFI_IF" ] && [ -z "$MOBILE_IF" ] && sleep $SLEEP_INTERVAL && continue

    ACTIVE=$(dumpsys connectivity | grep "ActiveNetwork" -A 3)

    # Wi-Fi
    if echo "$ACTIVE" | grep -q "WIFI"; then
        for IF in $WIFI_IF; do
            [ "$CURRENT_ALGO_WIFI" != "bbr2" ] && set_algorithm bbr2 $IF
        done
        CURRENT_ALGO_WIFI="bbr2"
        CURRENT_ALGO_MOBILE=""
    # Mobile
    elif echo "$ACTIVE" | grep -q "MOBILE"; then
        for IF in $MOBILE_IF; do
            [ "$CURRENT_ALGO_MOBILE" != "westwood" ] && set_algorithm westwood $IF
        done
        CURRENT_ALGO_MOBILE="westwood"
        CURRENT_ALGO_WIFI=""
    fi

    sleep $SLEEP_INTERVAL
done
