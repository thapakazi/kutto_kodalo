lets_put_laptop_in_sleep(){
    while true; do sleep 10s; systemctl suspend; sleep 10s; done
}

lets_go_home(){ lets_put_laptop_in_sleep;}
lets_go_office(){ lets_put_laptop_in_sleep;}
lets_sleep_now(){ lets_put_laptop_in_sleep;}
lets_go_other(){ lets_put_laptop_in_sleep;}

wifi_chodam(){
    SSID='very very hot-spot:P'
    PASSWD=${1:-1to4666667ate9}
  sudo create_ap wlan1 wlan0 "${SSID}" "${PASSWD}"
}
