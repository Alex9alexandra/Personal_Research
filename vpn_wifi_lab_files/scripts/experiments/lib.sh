# Shared helpers for the experiment scripts
vm() { local m="$1"; shift; vagrant ssh "$m" -c "$*" 2>/dev/null | tr -d '\r'; }
put() { # put <machine> <path> <content>
  local b64; b64=$(printf '%s\n' "$3" | base64 -w0)
  vagrant ssh "$1" -c "echo $b64 | base64 -d | sudo tee $2 >/dev/null && sudo chmod 644 $2" 2>/dev/null
}
tunnel_down() {
  vm client "sudo wg-quick down wg0; sudo systemctl stop openvpn-client@lab; sudo ikev2-down" >/dev/null
}
tunnel_up() {
  case $1 in
    W) vm client "sudo wg-quick up wg0" >/dev/null ;;
    O) vm client "sudo systemctl start openvpn-client@lab; for i in \$(seq 1 30); do ip link show tun0 >/dev/null 2>&1 && break; sleep 1; done" >/dev/null ;;
    I) vm client "sudo ikev2-up" >/dev/null ;;
  esac
}