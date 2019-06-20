#!/bin/bash
#
# Author: Pierre Pfister <ppfister@cisco.com>
#
# Largely inspired from contiv-VPP vagrant file.
#

set -ex
echo Args passed: [[ $@ ]]

nat64_prefix=$K8S_NAT64_PREFIX

echo "Installing required packages"
sudo apt-get install -y build-essential linux-headers-$(uname -r) dkms \
	gcc make pkg-config libnl-genl-3-dev autoconf \
		bind9

if [ ! -d "/home/vagrant/Jool" ]; then
	echo "Downloading Jool"
	git clone https://github.com/NICMx/Jool.git /home/vagrant/Jool.tmp
	mv /home/vagrant/Jool.tmp /home/vagrant/Jool
fi

if [ "$(sudo dkms status | grep "^jool")" = "" ]; then
	echo "Installing Jool kernel modules"
	( cd /home/vagrant/ && sudo dkms install Jool )
fi

echo "Compiling and installing Jool's user binaries"
sudo chown -R vagrant:vagrant /home/vagrant/Jool
( cd /home/vagrant/Jool && ./autogen.sh && ./configure )
make -C /home/vagrant/Jool
sudo make install -C /home/vagrant/Jool

echo "Configuring Jool"
sudo tee /etc/systemd/system/nat64.service << EOF
[Unit]
Description=Jool NAT64
After=network.target

[Service]
ExecStart=/root/nat64-setup.sh

[Install]
WantedBy=default.target
EOF

sudo tee /root/nat64-setup.sh << EOF
#!/bin/bash
modprobe jool pool6=$nat64_prefix/96 disabled
ip4_address=\$(ip -o addr show dev enp0s3 | sed 's,/, ,g' | awk '\$3=="inet" { print $4 }')

jool -4 --add $ip4_address 7000-8000
jool -4 -d
jool -6 -d
jool --enable
#jool -d
EOF

sudo chmod a+x /root/nat64-setup.sh

sudo systemctl start nat64.service
sudo systemctl enable nat64.service

echo "Configuring bind"
cat | sudo tee /etc/bind/named.conf.options << EOF
options {
  directory "/var/cache/bind";
  //dnssec-validation auto;
  auth-nxdomain no;
  listen-on-v6 { any; };
	forwarders {
	  8.8.8.8;
	};
	allow-query { any; };
	# Add prefix for Jool's pool6
	dns64 $nat64_prefix/96 {
	  exclude { any; };
	};
};
EOF

sudo service bind9 restart
systemctl status bind9
