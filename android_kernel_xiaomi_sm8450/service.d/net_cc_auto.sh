#!/system/bin/sh
LOG_TAG="net-cc-auto"
SLEEP_INTERVAL=15

set_algorithm() {
    ALGO=$1
    IFACE=$2

    if [ "$ALGO" = "bbr2" ]; then
        sysctl -w net.ipv4.tcp_congestion_control=bbr2
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

CURRENT_ALGO=""
while true; do
    get_interfaces
    [ -z "$WIFI_IF" ] && [ -z "$MOBILE_IF" ] && sleep $SLEEP_INTERVAL && continue
    ACTIVE=$(dumpsys connectivity | grep "ActiveNetwork" -A 3)

    if echo "$ACTIVE" | grep -q "WIFI"; then
        [ "$CURRENT_ALGO" != "bbr2" ] && set_algorithm bbr2 $WIFI_IF && CURRENT_ALGO="bbr2"
    elif echo "$ACTIVE" | grep -q "MOBILE"; then
        [ "$CURRENT_ALGO" != "westwood" ] && set_algorithm westwood $MOBILE_IF && CURRENT_ALGO="westwood"
    fi

    sleep $SLEEP_INTERVAL
done
