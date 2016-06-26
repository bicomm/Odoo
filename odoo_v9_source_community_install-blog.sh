#!/bin/bash 
################################################################################
# Script for installing Odoo V9 on Ubuntu 16.04 LTS (could be used for other version too)
# Author: Rémy lannemajou based on Yenthe Van Ginneken's work) 
#-------------------------------------------------------------------------------
# This script will install Odoo on your Ubuntu 16.04 server. It can install multiple Odoo instances
# in one Ubuntu because of the different xmlrpc_ports
#-------------------------------------------------------------------------------
# Make a new file:
# sudo nano odoo-install.sh
# Place this content in it and then make the file executable:
# sudo chmod +x odoo-install.sh
# Execute the script to install Odoo:
# ./odoo-install
################################################################################
 
##fixed parameters
#odoo

ODOO_USER="odoo-community"
ODOO_GROUP="odoo-community"
ODOO_HOME="/opt/$ODOO_USER"
#The default port where this Odoo instance will run under (provided you use the command -c in the terminal)
#Set to true if you want to install it, false if you don't need it or have it already installed.
INSTALL_WKHTMLTOPDF="True"
#Set the default Odoo port (you still have to use -c /etc/odoo-server.conf for example to use this.)
OE_PORT="8069"
#Choose the Odoo version which you want to install. For example: 9.0, 8.0, 7.0 or saas-6. When using 'trunk' the master version will be installed.
#IMPORTANT! This script contains extra libraries that are specifically needed for Odoo 9.0
OE_VERSION="9.0"
IS_ENTERPRISE="False"
#set the superadmin password
OE_SUPERADMIN="yourpassword"
ODOO_CONFIG="${ODOO_USER}-server"

##
###  WKHTMLTOPDF download links
## === Ubuntu Trusty x64 & x32 === (for other distributions please replace these two links,
## in order to have correct version of wkhtmltox installed, for a danger note refer to 
## https://www.odoo.com/documentation/8.0/setup/install.html#deb ):
WKHTMLTOX_X64=http://download.gna.org/wkhtmltopdf/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-amd64.deb
WKHTMLTOX_X32=http://download.gna.org/wkhtmltopdf/0.12/0.12.1/wkhtmltox-0.12.1_linux-trusty-i386.deb

#--------------------------------------------------
# Settings Server
#--------------------------------------------------
sudo mkdir /etc/$ODOO_USER
sudo chown $ODOO_USER:$ODOO_GROUP /etc/$ODOO_USER

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo apt-get update
sudo apt-get upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
echo -e "\n---- Install PostgreSQL Server ----"
sudo apt-get install postgresql -y

echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
sudo su - postgres -c "createuser -s $ODOO_USER" 2> /dev/null || true
sudo systemctl status postgresql

echo -e "\n----PostgreSQL Server installed  ----"


#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n---- Install tool packages ----"
sudo apt-get install wget subversion git bzr bzrtools python-pip gdebi-core -y
	
echo -e "\n---- Install python packages ----"
sudo apt-get install python-dateutil python-feedparser python-ldap python-libxslt1 python-lxml python-mako python-openid python-psycopg2 python-pybabel python-pychart python-pydot python-pyparsing python-reportlab python-simplejson python-tz python-vatnumber python-vobject python-webdav python-werkzeug python-xlwt python-yaml python-zsi python-docutils python-psutil python-mock python-unittest2 python-jinja2 python-pypdf python-decorator python-requests python-passlib python-pil -y

read -p "Python packages installed : Press enter to follow"

echo -e "\n---- Install python dev/dependencies packages ----"
sudo apt-get install libpq-dev libxml2-dev libxslt1-dev python-dev python-dev libldap2-dev libsasl2-dev libssl-dev -y

sudo -H pip install --upgrade pip	
echo -e "\n---- Install python libraries ----"
sudo -H pip install gdata psycogreen ofxparse
sudo -H pip install suds

echo -e "\n--- Install other required packages"
sudo apt-get install node-clean-css -y
sudo apt-get install node-less -y
sudo apt-get install python-gevent -y

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts on correct place for ODOO 9 ----"
  #pick up correct one from x64 & x32 versions:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n `basename $_url`
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi
	

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --shell=/bin/bash --home=$ODOO_HOME --gecos 'ODOO' --group $ODOO_GROUP


#The user should also be added to the sudo'ers group.
sudo adduser $ODOO_USER sudo
echo -e "password\npassword" | passwd $ODOO_USER

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$ODOO_USER
sudo chown $ODOO_USER:$ODOO_GROUP /var/log/$ODOO_USER


echo -e "\n==== Installing ODOO Server ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $ODOO_HOME/

if [ $IS_ENTERPRISE = "True" ]; then
    # Odoo Enterprise install!
	
	sudo su $ODOO_USER -c "mkdir $ODOO_HOME/enterprise"
    sudo su $ODOO_USER -c "mkdir $ODOO_HOME/enterprise/addons"
	
    echo -e "\n---- Adding Enterprise code under $ODOO_HOME/enterprise/addons ----"
    sudo git clone --depth 1 --branch 9.0 https://www.github.com/odoo/enterprise "$ODOO_HOME/enterprise/addons"

    echo -e "\n---- Installing Enterprise specific libraries ----"
    sudo apt-get install nodejs npm
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
    echo -e "\n--- Create symlink for node"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
else 
	sudo apt-get install nodejs npm
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
    echo -e "\n--- Create symlink for node"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    echo -e "\n---- Create custom module directory ----"
    sudo su $ODOO_USER -c "mkdir $ODOO_HOME/custom"
    sudo su $ODOO_USER -c "mkdir $ODOO_HOME/custom/addons" 
fi

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $ODOO_USER:$ODOO_GROUP $ODOO_HOME/*

#sudo -H pip install -r $ODOO_HOME/requirements.txt

echo -e "* Create server config file"
sudo cp $ODOO_HOME/debian/openerp-server.conf /etc/$ODOO_USER/${ODOO_CONFIG}.conf
sudo chown $ODOO_USER:$ODOO_USER /etc/$ODOO_USER/${ODOO_CONFIG}.conf
sudo chmod 640 /etc/$ODOO_USER/${ODOO_CONFIG}.conf

echo -e "* Change server config file"
sudo sed -i s/"db_user = .*"/"db_user = $ODOO_USER"/g /etc/$ODOO_USER/${ODOO_CONFIG}.conf
sudo sed -i s/"; admin_passwd.*"/"admin_passwd = $OE_SUPERADMIN"/g /etc/$ODOO_USER/${ODOO_CONFIG}.conf
sudo sed -i '/addons_path/d' /etc/$ODOO_USER/${ODOO_CONFIG}.conf
sudo su root -c "echo 'logfile = /var/log/$ODOO_USER/${ODOO_CONFIG}.log' >> /etc/$ODOO_USER/${ODOO_CONFIG}.conf"
sudo su root -c "echo 'data_dir = $ODOO_HOME/data' >> /etc/$ODOO_USER/${ODOO_CONFIG}.conf"

if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "echo 'addons_path=$ODOO_HOME/enterprise/addons,$ODOO_HOME/addons' >> /etc/$ODOO_USER/${ODOO_CONFIG}.conf"
else
    sudo su root -c "echo 'addons_path=$ODOO_HOME/addons,$ODOO_HOME/custom/addons' >> /etc/$ODOO_USER/${ODOO_CONFIG}.conf"
fi

echo -e "* Create startup file"
sudo su root -c "echo '#!/bin/sh' >> $ODOO_HOME/start.sh"
sudo su root -c "echo 'sudo -u $ODOO_USER $ODOO_HOME/openerp-server --config=/etc/$ODOO_USER/${ODOO_CONFIG}.conf' >> $ODOO_HOME/start.sh"
sudo chmod 755 $ODOO_HOME/start.sh

#--------------------------------------------------
# Adding ODOO as a deamon (initscript)
#--------------------------------------------------

echo -e "* Create init file"
cat <<EOF > ~/$ODOO_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Provides: $ODOO_CONFIG
# Required-Start: \$remote_fs \$syslog
# Required-Stop: \$remote_fs \$syslog
# Should-Start: \$network
# Should-Stop: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Enterprise Business Applications
# Description: ODOO Community Applications
### END INIT INFO
PATH=/bin:/sbin:/usr/bin
DAEMON=$ODOO_HOME/openerp-server
NAME=$ODOO_CONFIG
DESC=$ODOO_CONFIG

# Specify the user name (Default: odoo).
USER=$ODOO_USER

# Specify an alternate config file (Default: /etc/openerp-server.conf).
CONFIGFILE="/etc/$ODOO_USER/${ODOO_CONFIG}.conf"

# pidfile
PIDFILE=/var/run/\${NAME}.pid

# Additional options that are passed to the Daemon.
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] || return 1
pid=\`cat \$PIDFILE\`
[ -d /proc/\$pid ] && return 0
return 1
}

case "\${1}" in
start)
echo -n "Starting \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
stop)
echo -n "Stopping \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
echo "\${NAME}."
;;

restart|force-reload)
echo -n "Restarting \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$PIDFILE \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$PIDFILE \
--chuid \$USER --background --make-pidfile \
--exec \$DAEMON -- \$DAEMON_OPTS
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Usage: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;

esac
exit 0
EOF

echo -e "* Security Init File"
sudo mv ~/$ODOO_CONFIG /etc/init.d/$ODOO_CONFIG
sudo chmod 755 /etc/init.d/$ODOO_CONFIG
sudo chown root: /etc/init.d/$ODOO_CONFIG

echo -e "* Change default xmlrpc port"
sudo su root -c "echo 'xmlrpc_port = $OE_PORT' >> /etc/$ODOO_USER/${ODOO_CONFIG}.conf"

echo -e "* Start ODOO on Startup"
sudo update-rc.d $ODOO_CONFIG defaults

echo -e "* Starting Odoo Service"
sudo su root -c "/etc/init.d/$ODOO_CONFIG start"
echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $ODOO_USER"
echo "User PostgreSQL: $ODOO_USER"
echo "Code location: $ODOO_USER"
echo "Addons folder: $ODOO_HOME/addons/"
echo "Start Odoo service: sudo service $ODOO_CONFIG start"
echo "Stop Odoo service: sudo service $ODOO_CONFIG stop"
echo "Restart Odoo service: sudo service $ODOO_CONFIG restart"
echo "-----------------------------------------------------------"
