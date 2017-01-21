lets_go_home(){
    while true; do sleep 10s; systemctl suspend; done
}

lets_go_office(){
    lets_go_home
}

wifi_chodam(){
    SSID='very very hot-spot:P'
    PASSWD=${1:-1to4666667ate9}
  sudo create_ap wlan1 wlan0 "${SSID}" "${PASSWD}"
}
