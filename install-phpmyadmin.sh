#!/bin/bash

function usage {
	this=$(basename $0)
	cat <<-EOT
	Usage: $this [HTTP_AUTH_USERNAME]

	This script installs PHPMyAdmin and configures the "phpmyadmin" mysql account.
	It also adds HTTP authentication to PHPMyAdmin.
	It will first ask you for an HTTP authentication password and then it will ask you for the PHPMyAdmin account password later.

	If you need to change the HTTP authentication password, you can use "reset-pma-http-auth-password.sh" script.

	HTTP_AUTH_USERNAME can be any user name, your linux user name or another one.

	Example: $this johndoe

	This command will:

	- ask for a password for "johndoe"
	- create an HTTP authentication with user name "johndoe" and the specified password
	- install PHPMyAdmin
	- ask for a password for the "phpmyadmin" mysql account
	- and do some other things (see the source)
	EOT
}

if [ $# -lt 1 ]; then
	usage
	exit 1
else
	# settings
	http_auth_username="$1"

	cat <<-EOT
	HTTP_AUTH_USERNAME: $http_auth_username

	EOT

	read -p "Press [y/Y] to confirm: " -n 1 answer
	echo ""

	if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
		echo "canceled"
		exit
	fi
fi

# create http authentication password
if [ ! -f /etc/phpmyadmin/htpasswd.login ]; then
	echo "HTTP authentication password for login '$http_auth_username'"
	htpasswd -c ~/htpasswd.login $http_auth_username
fi

# install phpmyadmin
sudo apt install -y phpmyadmin

# grant all privileges to phpmyadmin account
echo "GRANT ALL PRIVILEGES ON *.* TO 'phpmyadmin'@'localhost' WITH GRANT OPTION;" | sudo mysql
echo "FLUSH PRIVILEGES;" | sudo mysql

# backup current config
if [ ! -f /etc/phpmyadmin/apache.conf.orig ]; then
	sudo cp /etc/phpmyadmin/apache.conf /etc/phpmyadmin/apache.conf.orig
fi

# enable phpmyadmin
sudo ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
sudo a2enconf phpmyadmin.conf

# enable http authentication password
if [ ! -f /etc/phpmyadmin/htpasswd.login ]; then
	sudo mv ~/htpasswd.login /etc/phpmyadmin/htpasswd.login
fi

# add http authentication
# AuthType Basic
# AuthName "phpMyAdmin"
# AuthUserFile /etc/phpmyadmin/htpasswd.login
# Require valid-user
#
count=$(grep "AuthUserFile /etc/phpmyadmin/htpasswd.login" /etc/phpmyadmin/apache.conf | wc -l)
if [ $count -eq 0 ]; then
	sudo sed -i "9i\AuthType Basic" /etc/phpmyadmin/apache.conf
	sudo sed -i "10i\AuthName \"phpMyAdmin\"" /etc/phpmyadmin/apache.conf
	sudo sed -i "11i\AuthUserFile /etc/phpmyadmin/htpasswd.login" /etc/phpmyadmin/apache.conf
	sudo sed -i "12i\Require valid-user" /etc/phpmyadmin/apache.conf
	sudo sed -i "13i\\\\" /etc/phpmyadmin/apache.conf
fi

# restart apache2
sudo systemctl restart apache2.service

