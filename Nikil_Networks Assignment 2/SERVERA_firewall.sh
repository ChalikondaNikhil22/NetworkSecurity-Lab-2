#!/bin/sh

IPT=/sbin/iptables
# NAT interface
NIF=enp0s9
# NAT IP address
NIP=`ip -f inet addr show $NIF | grep -Po 'inet \K[\d.]+'`

# Host-only interface
HIF=enp0s3
# Host-only IP addres
HIP='192.168.60.100'

# Set DNS nameserver to Google's DNS (8.8.8.8)

## Reset the firewall to a permissive but secure state

# Flush all rules in the FILTER table
$IPT -t filter -F
# Delete any user-defined chains in the FILTER table
$IPT -t filter -X
# Flush all rules in the NAT table
$IPT -t nat -F
# Delete any user-defined chains in the NAT table
$IPT -t nat -X
# Flush all rules in the MANGLE table
$IPT -t mangle -F
# Delete any user-defined chains in the MANGLE table
$IPT -t mangle -X
# Flush all rules in the RAW table
$IPT -t raw -F
# Delete any user-defined chains in the RAW table
$IPT -t raw -X

# Set default policies to drop all incoming, outgoing, and forwarded packets
$IPT -t filter -P INPUT DROP
$IPT -t filter -P OUTPUT DROP
$IPT -t filter -P FORWARD DROP


# Allow traffic through the tunnel for specific IPs
$IPT -A INPUT -s 192.168.70.6 -j ACCEPT
$IPT -A OUTPUT -d 192.168.70.6 -j ACCEPT

# Allow specific traffic forwarding between subnets
$IPT -A FORWARD -s 192.168.60.100/24 -d 192.168.80.100/24 -j ACCEPT
$IPT -A FORWARD -s 192.168.80.100/24 -d 192.168.60.100/24 -j ACCEPT

# Allow forwarding traffic through IPsec tunnel
$IPT -A FORWARD --match policy --dir in --pol ipsec --mode tunnel --tunnel-dst 192.168.70.6 -s 192.168.80.100/24 -d 192.168.60.100/24 -j ACCEPT
$IPT -A FORWARD --match policy --dir in --pol ipsec --mode tunnel --tunnel-dst 192.168.70.6 -s 192.168.60.100/24 -d 192.168.80.100/24 -j ACCEPT


# Allow traffic from/to the loopback interface
$IPT -A OUTPUT -o lo -j ACCEPT
$IPT -A INPUT -i lo -j ACCEPT

# Allow ICMP traffic for ping requests and replies
$IPT -A OUTPUT -p icmp --icmp-type 8 -j ACCEPT
$IPT -A INPUT -p icmp --icmp-type 0 -j ACCEPT


# Allow DNS requests to Google's DNS servers
$IPT -A OUTPUT -p udp -d $NS --dport 53 -j ACCEPT
$IPT -A INPUT -p udp -s $NS --sport 53 -j ACCEPT
$IPT -A OUTPUT -p tcp -d $NS --dport 53 -j ACCEPT
$IPT -A INPUT -p tcp -s $NS --sport 53 -j ACCEPT


# Enable stateful firewall for HTTP (80) and HTTPS (443) traffic
$IPT -A INPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
$IPT -A OUTPUT -p tcp -m multiport --sport 80,443 -m conntrack --ctstate ESTABLISHED -j ACCEPT
$IPT -A OUTPUT -p tcp -m multiport --dports 80,443 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
$IPT -A INPUT -p tcp -m multiport --sport 80,443 -m conntrack --ctstate ESTABLISHED -j ACCEPT

# Allow ICMP ping requests from Client A
$IPT -A INPUT -p icmp -s 192.168.60.111 -j ACCEPT
$IPT -A OUTPUT -p icmp -d 192.168.60.111 -j ACCEPT


# Allow SSH connections from Client A to Server A
$IPT -A INPUT -p tcp -s 192.168.60.111 --dport 22 -j ACCEPT
$IPT -A OUTPUT -p tcp -d 192.168.60.111 --sport 22 -j ACCEPT

# Enable IP forwarding on Server A
sysctl -w net.ipv4.ip_forward=1
sysctl -p

# Allow packet forwarding
$IPT -A FORWARD -i $HIF -j ACCEPT
$IPT -A FORWARD -i $NIF -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Enable Source NAT (SNAT)
$IPT -t nat -A POSTROUTING -j SNAT -o $NIF --to $NIP





