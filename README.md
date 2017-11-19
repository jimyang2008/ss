# Setup RPi as a wireless bridge
## Steps

To setup wireless bridge on a Raspberry Pi 3B, following steps need to followed strictly

```bash
STAIFNAME=wlan0
APIFNAME=wlan1
APIFMAC=b8:27:eb:1c:98:53
APIFIP=192.168.6.1

iw phy phy0 interface add $APIFNAME type __ap
ifconfig $APIFNAME hw ether $APIFMAC
ifconfig $APIFNAME $APIFIP

systemctl restart hostapd
systemctl restart dhcpcd
```

## Setup Components
### Setup virtual interface wlan1 - iw/ifconfig
```
ifconfig wlan0 down
iw phy phy0 interface add wlan1 type __ap
ifconfig wlan1 hw ether b8:27:eb:1c:98:53
```

### Setup static IP - dhcpcd

```
cat <<EOS > /etc/dhcpcd.conf
hostname
clientid
persistent
option rapid_commit
option domain_name_servers, domain_name, domain_search, host_name
option classless_static_routes
option ntp_servers
option interface_mtu
require dhcp_server_identifier
slaac private
interface wlan1
static ip_address=192.168.6.1/24
EOS
```

### Setup wireless hotspot - hostapd
```
cat <<EOS > /etc/hostapd/hostapd.conf
ssid=WiFiSSID
interface=wlan1
channel=1
driver=nl80211
hw_mode=g
macaddr_acl=0
auth_algs=1
wpa=2
wpa_passphrase=WifiPassword
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
rsn_pairwise=CCMP
EOS

#set DAEMON_CONF="/etc/hostapd/hostapd.conf" in /etc/default/hostapd

systemctl start hostapd
```

### Setup DHCP and DNS - dnsmasq

```
cat <<EOS >> /etc/dnsmasq.conf
no-dhcp-interface=lo,wlan0
bind-interfaces
dhcp-mac=set:client_is_a_pi,B8:27:EB:*:*:*
dhcp-reply-delay=tag:client_is_a_pi,2
dhcp-range=wlan1,192.168.6.100,192.168.6.200,12h
EOS
```

## Reference
* [Software access point](https://wiki.archlinux.org/index.php/Software_access_point)
* [Network bridge](https://wiki.archlinux.org/index.php/Network_bridge)        
* [hostapd Linux documentation page](https://wireless.wiki.kernel.org/en/users/Documentation/hostapd)
