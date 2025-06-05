function cleanup {
    echo "[CANCELLED] - ProxmoxNG - Installation cancelled by the user."
    exit 1
}

function pre_init {
    echo "[PRE_SETUP - Packages - STEP 1] - ProxmoxNG - Installing test repository ..."
    echo ""
    echo "deb http://download.proxmox.com/debian bookworm pvetest" >/etc/apt/sources.list.d/pve-development.list 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to add PVE utilities repository, make sure you have root privileges."
        echo ""
        exit 1
    fi

    echo "[PRE_SETUP - Packages - STEP 2] - ProxmoxNG - Updating repositories ..."
    echo ""
    apt update -y 2>/dev/null

    echo "[PRE_SETUP - Packages - STEP 3] - ProxmoxNG - Installing ProxmoxNG dependencies ..."
    echo ""
    apt-get install -y git python3 python3-venv build-essential python3-dev git-email debhelper pve-doc-generator libpod-parser-perl libtest-mockmodule-perl lintian pve-eslint sq keepalived 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to install ProxmoxNG dependencies, make sure you have root privileges and access to internet."
        echo ""
        exit 1
    fi
}

function directory_creation {
    echo ""
    echo "[PRE_SETUP - Directories - STEP 1] - ProxmoxNG - Setting up ProxmoxNG directories ..."
    echo ""

    echo ""
    echo "[PRE_SETUP - Directories - STEP 1.1] - ProxmoxNG - Creating main directory ..."
    echo ""
    mkdir /etc/proxmoxng >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        ls /etc/proxmoxng >/dev/null 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "[ERROR] - Failed to create /etc/proxmoxng directory, make sure you have root privileges."
            echo ""
            exit 1
        fi
    fi

    echo ""
    echo "[PRE_SETUP - Directories - STEP 1.2] - ProxmoxNG - Creating middleware config directory ..."
    echo ""
    mkdir /etc/proxmoxng/middleware >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        ls /etc/proxmoxng/middleware >/dev/null 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "[ERROR] - Failed to create /etc/proxmoxng/middleware directory, make sure you have root privileges."
            echo ""
            exit 1
        fi
    fi

    echo ""
    echo "[PRE_SETUP - Directories - STEP 1.3] - ProxmoxNG - Creating middleware executable directory ..."
    echo ""
    mkdir /usr/share/proxmoxng >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        ls /usr/share/proxmoxng >/dev/null 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "[ERROR] - Failed to create /usr/share/proxmoxng directory, make sure you have root privileges."
            echo ""
            exit 1
        fi
    fi
}

function installing_middleware {
    echo ""
    echo "[SETUP - Middleware - STEP 1] - ProxmoxNG - Installing ProxmoxNG middleware ..."
    echo ""

    echo ""
    echo "[SETUP - Middleware - STEP 1.1] - ProxmoxNG - Creating Python virtual environment..."
    echo ""
    python3 -m venv /usr/share/proxmoxng/.venv
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to create ProxmoxNG's python virtual environent, make sure you have root privileges."
        echo ""
        exit 1
    fi

    echo ""
    echo "[SETUP - Middleware - STEP 1.2] - ProxmoxNG - Activating Python virtual environment..."
    echo ""
    source /usr/share/proxmoxng/.venv/bin/activate >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to activate ProxmoxNG's python virtual enviroment, make sure you have root privileges."
        echo ""
        exit 1
    fi

    echo ""
    echo "[SETUP - Middleware - STEP 1.3] - ProxmoxNG - Installing ProxmoxNG..."
    echo ""
    pip install -i https://test.pypi.org/simple/ --upgrade --no-deps proxmoxng 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to install ProxmoxNG middleware, make sure you have root privileges and access to internet."
        echo ""
        exit 1
    fi
}

#https://gist.github.com/kwmiebach/e42dc4a43d5a2a0f2c3fdc41620747ab
get_toml_value() {
    local file=$1
    local section=$2
    local key=$3

    # Extract lines between [section] and the next [ or end of file
    sed -n "/^\[$section\]/,/^\[/p" "$file" | \
    sed '1d;/^\[.*\]/d' | \
    grep -E "^$key[[:space:]]*=" | \
    head -n 1 | \
    cut -d '=' -f2- | \
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//'
}

echo ""
echo "[----------------------- PROXMOXNG INSTALLER -----------------------]"
echo ""
OPTION=$(whiptail --title "ProxmoxNG Installer" --menu "Choose an option" 25 78 16 \
    "1)" "Full installation - Normal Mode (Recommended)" \
    "2)" "Full installation - Automatic Mode" \
    "3)" "Full installation - Manual Mode" \
    "4)" "Update the Middleware software" \
    3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
    cleanup
fi

pre_init
directory_creation
installing_middleware

case "$OPTION" in
"1)")
    echo "[INSTALLING] - ProxmoxNG - Starting full installation ..."

    IP=$(whiptail --inputbox "Please enter the middleware IP address. The FQDN needs to resolve this ip address. \n Ex: 192.168.100.100" 10 60 --title "Set Middleware IP Address." 3>&1 1>&2 2>&3)

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

    echo ""
    echo "Middleware IP Address: $IP"
    echo ""

    PRIORITY=$(whiptail --inputbox "Please enter the keepalived priority value. Note: Each node needs to have a different priority. Higher number, higher priority. \n Ex: 100" 10 60 --title "Set Keepalived priority for this node." 3>&1 1>&2 2>&3)

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

    echo ""
    echo "Keepalived priority value: $PRIORITY"
    echo ""

    echo ""
    echo "Writing keepalived configuration file ..."
    echo ""
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
    }" >/etc/keepalived/keepalived.conf

    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to write keepalived configuration file, make sure you have root privileges."
        echo ""
        exit 1
    fi

    DB=$(whiptail --inputbox "Please enter the ProxmoxNG database location. This location needs to be accessible by all nodes. \n Ex: /mnt/sharedDisk/middleware/" 10 60 --title "Set ProxmoxNG Database Location" 3>&1 1>&2 2>&3)

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

    ls "$DB" >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - The database location is invalid or the directory does not exist."
        echo ""
        exit 1
    fi

    echo ""
    echo "ProxmoxNG Database Location: $DB"
    echo ""

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

    echo ""
    echo "Proxmox Username: $USER"
    echo ""

    while [ $PASSWORD != $CONFIRM_PASSWORD ]; do
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
        fi
    done

    DNS_ENTRY=$(whiptail --inputbox "Please insert a FQDN for the middleware (it has to be an authorized one and with valid certificates). \n Ex: domain.tld" --title "Set Middleware FQDN" 10 60 3>&1 1>&2 2>&3)

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

    echo ""
    echo "Middleware FQDN: $DNS_ENTRY"
    echo ""

    CERT_PATH=$(whiptail --inputbox "Please insert the certificate filepath for the middleware's DNS entry. Note: Needs to accessible by all nodes \n Ex: /mnt/sharedDisk/middleware/cert.pem" --title "Set Certificate Filepath" 10 60 3>&1 1>&2 2>&3)

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

    cat "$CERT_PATH" >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - The certificate filepath is invalid or the file does not exist."
        echo ""
        exit 1
    fi

    KEY_PATH=$(whiptail --inputbox "Please insert the key filepath for the certificate for the middleware's DNS entry. Note: Needs to accessible by all nodes \n Ex: /mnt/sharedDisk/middleware/key.pem" --title "Set Key Filepath" 10 60 3>&1 1>&2 2>&3)

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

    cat "$KEY_PATH" >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - The key filepath is invalid or the file does not exist."
        echo ""
        exit 1
    fi

    PUSHOVER_USER=$(whiptail --inputbox "(Optional) Please enter the Pushover username:" 10 60 --title "Set Proxmox Username" 3>&1 1>&2 2>&3)

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
cert=\"$CERT_PATH\"
key=\"$KEY_PATH\"" >/etc/proxmoxng/middleware/config.toml

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

[keepalived]
ip=\"$IP\"

[cert]
cert=\"$CERT_PATH\"
key=\"$KEY_PATH\"" >/etc/proxmoxng/middleware/config.toml
        if [ $? -ne 0 ]; then
            echo "[ERROR] - Failed to create /etc/proxmoxng/middleware/config.toml file, make sure you have root privileges."
            echo ""
            exit 1
        fi
    fi
    ;;
"2)")
    echo "[INSTALLING] - ProxmoxNG - Starting full installation in automatic mode ..."

    cat <<EOF | sed 's/^ *//' > /etc/proxmoxng/middleware/example.auto_config.toml
        #Example of automatic configuration file
        #Change the name of the file after editing
        [database]
        # Ex: /mnt/sharedDisk/middleware/
        uri="<db_path>"

        [proxmox]
        # Ex: root@pam
        user="<user>"
        password="<password>"

        [keepalived]
        # Ex: 192.168.100.100
        ip="<ip_address>"
        # Ex: 100
        priority="<node_priority>"

        #[pushover]
        #token="<application_token>"
        #user="<user_token>"

        [cert]
        # Ex: /mnt/sharedDisk/middleware/cert.pem
        cert="<cert_path>"
        # Ex: /mnt/sharedDisk/middleware/key.pem
        key="<key_path>"
        # Ex: domain.tld
        fqdn="<fqdn>"
EOF

    filepath=$(whiptail --inputbox "Please enter the path to the ProxmoxNG auto-configuration file. \n Ex: /etc/proxmoxng/middleware/auto_config.toml \n Example file located in: \n /etc/proxmoxng/middleware/example.auto_config.toml" 15 60  /etc/proxmoxng/middleware/auto_config.toml --title "Set ProxmoxNG Configuration File Path" 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then
        cleanup
    fi

    if [ -z "$filepath" ]; then
        echo "[ERROR] - You must set a valid ProxmoxNG auto-configuration file path."
        echo ""
        exit 1
    fi

    db=$(get_toml_value "$filepath" "database" "uri")
    echo "[INFO] - ProxmoxNG - Database location: $db"
    ls "$db" >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - The database location is invalid or the directory does not exist."
        echo ""
        exit 1
    fi

    ip=$(get_toml_value "$filepath" "keepalived" "ip")
    echo "[INFO] - ProxmoxNG - IP: $ip"
    if [[ ! $ip =~ ^((25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})$ ]]; then
        echo "[ERROR] - The IP address in the configuration file is invalid."
        echo ""
        exit 1
    fi

    priority=$(get_toml_value "$filepath" "keepalived" "priority")
    if [[ ! $priority =~ ^[0-9]{1,3}$ ]]; then
        echo "[ERROR] - The priority value in the configuration file is invalid."
        echo ""
        exit 1
    fi

    user=$(get_toml_value "$filepath" "proxmox" "user")
    if [ -z "$user" ]; then
        echo "[ERROR] - The Proxmox username in the configuration file is invalid."
        echo ""
        exit 1
    fi

    password=$(get_toml_value "$filepath" "proxmox" "password")
    if [ -z "$password" ]; then
        echo "[ERROR] - The Proxmox password in the configuration file is invalid."
        echo ""
        exit 1
    fi

    cert=$(get_toml_value "$filepath" "cert" "cert")
    ls "$cert" >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - The certificate filepath in the configuration file is invalid or the file does not exist."
        echo ""
        exit 1
    fi

    key=$(get_toml_value "$filepath" "cert" "key")
    ls "$key" >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - The key filepath in the configuration file is invalid or the file does not exist."
        echo ""
        exit 1
    fi

    fqdn=$(get_toml_value "$filepath" "cert" "fqdn")
    echo "$fqdn"
    if [[ -z "$fqdn" ]]; then
        echo "[ERROR] - The FQDN in the configuration file is invalid."
        echo ""
        exit 1
    fi

    pushover_user=$(get_toml_value "$filepath" "pushover" "user")
    pushover_token=$(get_toml_value "$filepath" "pushover" "token")
    if [[ -n "$pushover_user" && -z "$pushover_token" ]]; then
        echo "[ERROR] - The Pushover token in the configuration file is invalid."
        echo ""
        exit 1
    fi

    if [[ -z "$pushover_user" && -n "$pushover_token" ]]; then
        echo "[ERROR] - The Pushover user in the configuration file is invalid."
        echo ""
        exit 1
    fi

    echo ""
    echo "Writing keepalived configuration file ..."
    echo ""
    cat <<EOF | sed 's/^[\t ]//' > /etc/keepalived/keepalived.conf
	vrrp_instance VI_1 {
		interface vmbr0
		virtual_router_id 101
		state BACKUP
		nopreempt
		priority $priority
		advert_int 1
		authentication {
			auth_type PASS
			auth_pass 12345678
		}
		virtual_ipaddress {
			$ip
		}
	}
EOF
    if [[ $pushover_user =~ ^[a-zA-Z0-9]{1,30}$ ]]; then
        echo "[database]
uri=\""${db%/}/db.sqlite"\"

[proxmox]
ip=\"127.0.0.1\"
port=\"8006\"
user=\"$user\"
password=\"$password\"

[keepalived]
ip=\"$ip\"

[pushover]
token=\"$pushover_token\"
user=\"$pushover_user\"
    
[cert]
cert=\"$cert\"
key=\"$key\"" >/etc/proxmoxng/middleware/config.toml

    else
        echo "[database]
uri=\""${db%/}/db.sqlite"\"

[proxmox]
ip=\"127.0.0.1\"
port=\"8006\"
user=\"$user\"
password=\"$password\"

[keepalived]
ip=\"$ip\"

[cert]
cert=\"$cert\"
key=\"$key\"" >/etc/proxmoxng/middleware/config.toml
    fi

    DNS_ENTRY=$fqdn
    ;;

"3)")
	echo "[INSTALLING] - ProxmoxNG - Starting full installation in manual mode ..."
	if whiptail --title "ProxmoxNG Installer" --yesno "Are you sure you want to continue? This is an advanced feature. You are expected to manually configure all configuration files." 8 78 3>&1 1>&2 2>&3; then
		echo "User selected Yes, exit status was $?."
	else
		echo "User selected No, exit status was $?."
	fi
	
	;;
"4)")
    echo "[UPDATING] - ProxmoxNG - Starting update of the Middleware software ..."
    echo ""
    echo "[INSTALL] - ProxmoxNG - Updating ProxmoxNG middleware ..."
    echo ""
    source /usr/share/proxmoxng/.venv/bin/activate >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to activate ProxmoxNG's python virtual enviroment, make sure you have root privileges and that you already have the ProxmoxNG installed."
        echo ""
        exit 1
    fi
    pip install -i https://test.pypi.org/simple/ --upgrade --no-deps proxmoxng 2>/dev/null
    echo ""
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to update ProxmoxNG middleware, make sure you have root privileges and access to internet."
        echo ""
        exit 1
    fi
    echo "[SETUP] - ProxmoxNG - Updating ProxmoxNG service ..."
    echo ""
    systemctl restart proxmoxng.service >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to restart ProxmoxNG service, make sure you have root privileges and that you already have the ProxmoxNG installed."
        echo ""
        exit 1
    fi
    echo "[FINISH] - ProxmoxNG - Update finished successfully."
    exit 0
    ;;
esac

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
" >/etc/systemd/system/proxmoxng.service

systemctl enable --now proxmoxng.service

echo ""
echo "[INSTALL - STEP 2] - ProxmoxNG - Downloading ProxmoxNG Interface..."
echo ""
mkdir /etc/proxmoxng/interface >/dev/null 2>/dev/null
git clone https://github.com/rodrigo-gom3s/pve-manager.git /etc/proxmoxng/interface/pve-manager >/dev/null 2>/dev/null
if [ $? -ne 0 ]; then
    ls /etc/proxmoxng/interface/pve-manager >/dev/null 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "[ERROR] - Failed to create /etc/proxmoxng directory, make sure you have root privileges."
        echo ""
        exit 1
    fi
fi

sed -i "s/domain\.tld/${DNS_ENTRY}/g" /etc/proxmoxng/interface/pve-manager/www/manager6/window/NHACreateJSON.js 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[ERROR] - Failed to update the FQDN in NHACreateJSON.js, make sure you have root privileges."
    echo ""
    exit 1
fi
sed -i "s/domain\.tld/${DNS_ENTRY}/g" /etc/proxmoxng/interface/pve-manager/www/manager6/window/NHAExternalMigration.js 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[ERROR] - Failed to update the FQDN in NHAExternalMigration.js, make sure you have root privileges."
    echo ""
    exit 1
fi
sed -i "s/domain\.tld/${DNS_ENTRY}/g" /etc/proxmoxng/interface/pve-manager/www/manager6/window/NHAFaultTolerance.js 2>/dev/null
if [ $? -ne 0 ]; then
    echo "[ERROR] - Failed to update the FQDN in NHAFaultTolerance.js, make sure you have root privileges."
    echo ""
    exit 1
fi

echo "[INSTALL - STEP 3] - ProxmoxNG - Compiling ProxmoxNG ..."
echo ""
cd /etc/proxmoxng/interface/pve-manager && make >/dev/null 2>/dev/null

cd /etc/proxmoxng/interface/pve-manager/www && make install >/dev/null 2>/dev/null
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
