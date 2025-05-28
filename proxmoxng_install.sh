echo ""
echo "[----------------------- PROXMOXNG INSTALLER -----------------------]"
echo ""
TESTE=$(whiptail --title "ProxmoxNG Installer" --menu "Choose an option" 25 78 16 \
"1)" "Make a full installation of the ProxmoxNG" \
"2)" "Update the Middleware software" \
3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    echo "Cancelled."
    exit 1
fi

case "$TESTE" in
  "1)")
    echo "[INSTALLING] - ProxmoxNG - Starting full installation ..."
    ;;
  "2)")
    echo "[UPDATING] - ProxmoxNG - Starting update of the Middleware software ..."
    echo ""
    echo "[INSTALL] - ProxmoxNG - Updating ProxmoxNG middleware ..."
    echo ""
    source /usr/share/proxmoxng/.venv/bin/activate > /dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to activate ProxmoxNG's python virtual enviroment, make sure you have root privileges and that you already have the ProxmoxNG installed."
        echo ""
        exit 1
    fi
    pip install -i https://test.pypi.org/simple/ --upgrade --no-deps proxmoxng  2>/dev/null
    echo ""
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to update ProxmoxNG middleware, make sure you have root privileges and access to internet."
        echo ""
        exit 1
    fi
    echo "[SETUP] - ProxmoxNG - Updating ProxmoxNG service ..."
    echo ""
    systemctl restart proxmoxng.service > /dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to restart ProxmoxNG service, make sure you have root privileges and that you already have the ProxmoxNG installed."
        echo ""
        exit 1
    fi
    echo "[FINISH] - ProxmoxNG - Update finished successfully."
    exit 0
    ;;
esac

echo "[SETUP - STEP 1] - ProxmoxNG - Updating system and installing ProxmoxNG dependencies ..."
echo ""
echo "deb http://download.proxmox.com/debian bookworm pvetest" > /etc/apt/sources.list.d/pve-development.list 2>/dev/null

if [ $? -ne 0 ]; then
    echo "[ERROR] - Failed to add PVE utilities repository, make sure you have root privileges."
    echo ""
    exit 1
fi

apt-get update -y 2>/dev/null
apt-get upgrade -y 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[ERROR] - Failed to update system, make sure you have root privileges and access to internet"
    echo ""
fi

apt-get install -y git python3 python3-venv build-essential git-email debhelper pve-doc-generator libpod-parser-perl libtest-mockmodule-perl lintian pve-eslint sq 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[ERROR] - Failed to install ProxmoxNG dependencies, make sure you have root privileges and access to internet."
    echo ""
    exit 1
fi

echo ""
echo "[SETUP - STEP 2] - ProxmoxNG - Setting up ProxmoxNG directories ..."
echo ""

mkdir /etc/proxmoxng > /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    ls /etc/proxmoxng > /dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to create /etc/proxmoxng directory, make sure you have root privileges."
        echo ""
        exit 1
    fi
fi

mkdir /etc/proxmoxng/middleware > /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    ls /etc/proxmoxng/middleware > /dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to create /etc/proxmoxng/middleware directory, make sure you have root privileges."
        echo ""
        exit 1
    fi
fi

mkdir /usr/share/proxmoxng > /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    ls /usr/share/proxmoxng > /dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to create /usr/share/proxmoxng directory, make sure you have root privileges."
        echo ""
        exit 1
    fi
fi

python3 -m venv /usr/share/proxmoxng/.venv

if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to create ProxmoxNG's python virtual enviroment, make sure you have root privileges."
        echo ""
        exit 1
fi


echo "[SETUP - STEP 3] - ProxmoxNG - Setting up Keepalived ..."
echo ""

apt-get install keepalived -y

if [ $? -ne 0 ]; then
    echo "[ERROR] - Failed to install keepailved, make sure you have root privileges and access to the internet."
    echo ""
fi

IP=$(whiptail --inputbox "Please enter the cluster IP address:" 10 60 --title "Set Cluster IP Address" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    echo "[ERROR] - You must insert a virtual IP to your Proxmox cluster."
    echo ""
    exit 1
fi

if [[ ! $IP =~ ^((25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})$ ]]; then
        echo "[ERROR] - You must insert a valid virtual IP."
        echo ""
        exit 1
fi

PRIORITY=$(whiptail --inputbox "Please enter the keepalived node priority:" 10 60 --title "Set Keepalived Node Priority" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    echo "[ERROR] - You must set a keepalived node priority for this node."
    echo ""
    exit 1
fi

if [[ ! $PRIORITY =~ ^[0-9]{1,3}$ ]]; then
        echo "[ERROR] - You must set a valid keepalived node priority for this node."
        echo ""
        exit 1
fi

echo "vrrp_instance VI_1
	interface vmbr0
	virtual_router_id 101
	state BACKUP
	nopreempt
	priority $PRIORITY
	advert_int 1
	authentication {
		auth_type PASS
		auth_pass 12345678
	}
	virtual_ipaddress {
		$IP
	}
}" > /etc/keepalived/keepalived.conf

echo ""
echo "[SETUP - STEP 4] - ProxmoxNG - Setting up ProxmoxNG middleware ..."
echo ""

DB=$(whiptail --inputbox "Please enter the ProxmoxNG database location:" 10 60 --title "Set ProxmoxNG Database Location" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    echo "[ERROR] - You must set a location for the ProxmoxNG database."
    echo ""
    exit 1
fi

if [ -z "$DB" ]; then
    echo "[ERROR] - You must set a location for the ProxmoxNG database."
    echo ""
    exit 1
fi

USER=$(whiptail --inputbox "Please enter the Proxmox username:" --title "Set Proxmox Username" 10 60 root@pam 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    echo "[ERROR] - You must set the Proxmox username."
    echo ""
    exit 1
fi

if [ -z "$USER" ]; then
    echo "[ERROR] - You must set the Proxmox username."
    echo ""
    exit 1
fi

while [ $PASSWORD != $CONFIRM_PASSWORD ] 
do
    PASSWORD=$(whiptail --passwordbox "Please enter the Proxmox user password:" 10 60 --title "Set Proxmox User Password" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        echo "[ERROR] - You must set the Proxmox password."
        echo ""
        exit 1
    fi

    if [ -z "$PASSWORD" ]; then
        echo "[ERROR] - You must set the Proxmox password."
        echo ""
        exit 1
    fi

    CONFIRM_PASSWORD=$(whiptail --passwordbox "Please confirm the Proxmox user password:" 10 60 --title "Confirm Proxmox User Password" 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ] || [ -z "$CONFIRM_PASSWORD" ]; then
        echo "[ERROR] - You must confirm the Proxmox password."
        echo ""
        exit 1
    fi

    if [ "$PASSWORD" != "$CONFIRM_PASSWORD" ]; then
        whiptail --title "Password validation failed" --infobox "The passwords do not match, please try again." 10 60
        echo ""
        exit 1
    fi
done

DNS_ENTRY=$(whiptail --inputbox "Please insert a FQDN for the middleware (it has to be an authorized one):" --title "Set Middleware FQDN" 10 60  3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    echo "[ERROR] - You must set a valid FQDN."
    echo ""
    exit 1
fi

if [[ -z "$DNS_ENTRY" || ! "$DNS_ENTRY" =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
    echo "[ERROR] - You must set a valid FQDN"
    echo ""
    exit 1
fi

sed -i "s|domain\.tld|$DNS_ENTRY|g" /etc/proxmoxng/interface/pve-manager/www/manager6/window/NHACreateJSON.js
sed -i "s|domain\.tld|$DNS_ENTRY|g" /etc/proxmoxng/interface/pve-manager/www/manager6/window/NHAExternalMigration.js
sed -i "s|domain\.tld|$DNS_ENTRY|g" /etc/proxmoxng/interface/pve-manager/www/manager6/window/NHAFaultTolerance.js


CERT_PATH=$(whiptail --inputbox "Please insert the certificate filepath for the middleware's DNS entry:" --title "Set Certificate Filepath" 10 60  3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    echo "[ERROR] - You must set the certificate filepath."
    echo ""
    exit 1
fi

if [ -z "$CERT_PATH" ]; then
    echo "[ERROR] - You must set the certificate filepath"
    echo ""
    exit 1
fi

KEY_PATH=$(whiptail --inputbox "Please insert the key filepath for the certificate:" --title "Set Key Filepath" 10 60  3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    echo "[ERROR] - You must set the key filepath."
    echo ""
    exit 1
fi

if [ -z "$KEY_PATH" ]; then
    echo "[ERROR] - You must set the key filepath"
    echo ""
    exit 1
fi


PUSHOVER_USER=$(whiptail --inputbox "Please enter the Pushover username:" 10 60 --title "Set Proxmox Username" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    echo "[ERROR] - You must set the Pushover username."
    echo ""
    exit 1
fi

if [[ $PUSHOVER_USER =~ ^[a-zA-Z0-9]{1,30}$ ]]; then
        PUSHOVER_TOKEN=$(whiptail --inputbox "Please enter the Pushover token:" 10 60 --title "Set Proxmox Token" 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]; then
            echo "[ERROR] - You must set the Pushover token."
            echo ""
            exit 1
        fi
        if [ -z "$PUSHOVER_TOKEN" ]; then
            echo "[ERROR] - You must set the Proxmox token."
            echo ""
            exit 1
        fi

echo "[database]
uri=\""${DB%/}/db.sqlite"\"

[proxmox]
ip=\"127.0.0.1\"
port=\"8006\"
user=\"$USER\"
password=\"$PASSWORD\"

[keepalived]
ip=\"$IP\"

[pushover]
token=\"$PUSHOVER_TOKEN\"
user=\"$PUSHOVER_USER\"
[cert]
cert=\"/etc/proxmoxng/middleware/cert.pem\"
key=\"/etc/proxmoxng/middleware/key.pem\"" > /etc/proxmoxng/middleware/config.toml

if [ $? -ne 0 ]; then
    echo "[ERROR] - Failed to create /etc/proxmoxng/middleware/config.toml file, make sure you have root privileges."
    echo ""
    exit 1
fi

fi

if [[ ! $PUSHOVER_USER =~ ^[a-zA-Z0-9]{1,30}$ ]]; then
echo "[database]
uri=\""${DB%/}/db.sqlite"\"

[proxmox]
ip=\"127.0.0.1\"
port=\"8006\"
user=\"$USER\"
password=\"$PASSWORD\"


[cert]
cert=\"/etc/proxmoxng/middleware/cert.pem\"
key=\"/etc/proxmoxng/middleware/key.pem\"
" > /etc/proxmoxng/middleware/config.toml
if [ $? -ne 0 ]; then
    echo "[ERROR] - Failed to create /etc/proxmoxng/middleware/config.toml file, make sure you have root privileges."
    echo ""
    exit 1
fi
fi

echo "[INSTALL - STEP 1] - ProxmoxNG - Installing ProxmoxNG middleware ..."
echo ""
source /usr/share/proxmoxng/.venv/bin/activate > /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[ERROR] - Failed to activate ProxmoxNG's python virtual enviroment, make sure you have root privileges."
    echo ""
    exit 1
fi

pip install -i https://test.pypi.org/simple/ --no-deps proxmoxng  2>/dev/null
if [ $? -ne 0 ]; then
    echo "[ERROR] - Failed to install ProxmoxNG middleware, make sure you have root privileges and access to internet."
    echo ""
    exit 1
fi


echo ""
echo "[INSTALL - STEP 2] - ProxmoxNG - Creating Service Daemon ..."
echo ""
echo "
[Unit]
Description=ProxmoxNG Middlware Daemon
After=network.target

[Service]
User=root
Group=root
ExecStart=/usr/share/proxmoxng/.venv/bin/proxmoxng
Restart=always

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/proxmoxng.service

systemctl enable --now proxmoxng.service

echo ""
echo "[INSTALL - STEP 2] - ProxmoxNG - Downloading ProxmoxNG ..."
echo ""
mkdir /etc/proxmoxng/interface > /dev/null 2>/dev/null
git clone https://github.com/rodrigo-gom3s/pve-manager.git /etc/proxmoxng/interface/pve-manager > /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    ls /etc/proxmoxng/interface/pve-manager > /dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to create /etc/proxmoxng directory, make sure you have root privileges."
        echo ""
        exit 1
    fi
fi

sed 

echo "[INSTALL - STEP 3] - ProxmoxNG - Compiling ProxmoxNG ..."
echo ""
cd /etc/proxmoxng/interface/pve-manager && make	> /dev/null 2>/dev/null


cd /etc/proxmoxng/interface/pve-manager/www && make install > /dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[ERROR] - Failed to compile ProxmoxNG WWW, make sure you have root privileges."
    echo ""
    exit 1
fi

echo "[FINISH] - ProxmoxNG - Installation finished successfully."
echo ""
echo "[--------------------------------------------------------------------------------]"
echo ""
exit 0