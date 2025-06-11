_m_scrcpy_sig_raw(){
    scrcpy --select-tcpip --always-on-top "${@}"
}

_m_scrcpy_sig_with_basics(){
    _m_scrcpy_sig_raw --window-title=/dev/phone "${@}"
}

m_p(){
    _m_scrcpy_sig_with_basics "${@}"
}

m_p_cam(){
    _m_scrcpy_sig_raw \
        --video-source=camera \
        --orientation=270 \
        --camera-facing=front \
        --camera-ar=1:1 \
        "${@}"
}

m_pyt(){
    set -xv
    device=$(_m_adb_devices|head -1)
    adb -s $device shell am start -a android.intent.action.VIEW -d "${1}" com.google.android.youtube
    _m_scrcpy_sig_with_basics --window-title="youtube:: ${1}" ${2}
    set +xv
}

_m_adb_devices(){
    adb devices -l|awk 'NR>1 && NF {print $1}'
}

_m_adb_device_1(){
    adb devices -l|awk 'NR>1 && NF {print $1}'|head -1
}
