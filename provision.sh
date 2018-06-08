#!/usr/bin/env bash
# ==============================================================================
#
# Community Hass.io Add-ons: Vagrant
#
# Provisions a Vagrant guest with Hass.io
#
# ==============================================================================
set -o errexit  # Exit script when a command exits with non-zero status
set -o errtrace # Exit on error inside any functions or sub-shells
set -o nounset  # Exit script on use of an undefined variable
set -o pipefail # Return exit status of the last command in the pipe that failed

# ==============================================================================
# GLOBALS
# ==============================================================================
readonly EX_OK=0
readonly HASSIO_INSTALLER="https://raw.githubusercontent.com/home-assistant/hassio-build/master/install/hassio_install"
readonly DOCKER_DOWNLOAD="https://download.docker.com/linux"
readonly NETDATA_INSTALLER="https://my-netdata.io/kickstart-static64.sh"
readonly APT_REQUIREMENTS=(
    apt-transport-https
    avahi-daemon
    ca-certificates
    curl
    dbus
    jq
    socat
    software-properties-common
    apparmor-utils
    network-manager
)

# ==============================================================================
# SCRIPT LOGIC
# ==============================================================================

# ------------------------------------------------------------------------------
# Installs all required software packages and tools
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
install_requirements() {
    apt-get update
    apt-get install -y "${APT_REQUIREMENTS[@]}"
}

# ------------------------------------------------------------------------------
# Installs the Docker engine
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
install_docker() {
    local os
    local lsb_release

    os=$(. /etc/os-release; echo "${ID}")
    lsb_release=$(lsb_release -cs)

   # curl -fsSL "${DOCKER_DOWNLOAD}/${os}/gpg" | sudo apt-key add -
   curl -fsSL https://mirrors.ustc.edu.cn/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
    
   # add-apt-repository \
    #    "deb [arch=amd64] ${DOCKER_DOWNLOAD}/${os} ${lsb_release} stable"
    
    add-apt-repository \
    "deb [arch=amd64] https://mirrors.ustc.edu.cn/docker-ce/linux/ubuntu \
    $(lsb_release -cs) stable"
        
    cat >>/etc/apt/sources.list<<EOF
# deb cdrom:[Ubuntu 16.04 LTS _Xenial Xerus_ - Release amd64 (20160420.1)]/ xenial main restricted
deb-src http://archive.ubuntu.com/ubuntu xenial main restricted #Added by software-properties
deb http://mirrors.aliyun.com/ubuntu/ xenial main restricted
deb-src http://mirrors.aliyun.com/ubuntu/ xenial main restricted multiverse universe #Added by software-properties
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates main restricted
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-updates main restricted multiverse universe #Added by software-properties
deb http://mirrors.aliyun.com/ubuntu/ xenial universe
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates universe
deb http://mirrors.aliyun.com/ubuntu/ xenial multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-updates multiverse
deb http://mirrors.aliyun.com/ubuntu/ xenial-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-backports main restricted universe multiverse #Added by software-properties
deb http://archive.canonical.com/ubuntu xenial partner
deb-src http://archive.canonical.com/ubuntu xenial partner
deb http://mirrors.aliyun.com/ubuntu/ xenial-security main restricted
deb-src http://mirrors.aliyun.com/ubuntu/ xenial-security main restricted multiverse universe #Added by software-properties
deb http://mirrors.aliyun.com/ubuntu/ xenial-security universe
deb http://mirrors.aliyun.com/ubuntu/ xenial-security multiverse
EOF

    apt-get update
    apt-get install -y docker-ce

    usermod -aG docker ubuntu
    
    # add mirror for china uers
    cat >>/etc/docker/daemon.json<<EOF
    {
        "registry-mirrors": ["https://registry.docker-cn.com"]
    }
    EOF
   
    systemctl daemon-reload
    systemctl restart docker
    
}

# ------------------------------------------------------------------------------
# Installs and starts netdata
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
install_netdata() {
    curl -s "${NETDATA_INSTALLER}" > /tmp/kickstart-netdata.sh
    bash /tmp/kickstart-netdata.sh --dont-wait
    rm /tmp/kickstart-netdata.sh
}

# ------------------------------------------------------------------------------
# Installs and starts Portainer
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
install_portainer() {
    mkdir -p /usr/share/portainer
    
    docker pull portainer/portainer:latest

    docker create \
        --name=portainer \
        --restart=always \
        -v /usr/share/portainer:/data \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -p 9000:9000 \
        portainer/portainer \
        -H unix:///var/run/docker.sock \
        --no-auth

    docker start portainer
}

# ------------------------------------------------------------------------------
# Installs and starts Hass.io
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
install_hassio() {
    curl -sL "${HASSIO_INSTALLER}" | bash -s
}


# ------------------------------------------------------------------------------
# Shows a message on how to connect to Home Assistant, including the
# dynamic IP the guest was given.
#
# Arguments:
#   None
# Returns:
#   None
# ------------------------------------------------------------------------------
show_post_up_message() {
    local ip_public
    local ip_private
    
    ip_public=$(ip -f inet -o addr show enp0s8 | cut -d\  -f 7 | cut -d/ -f 1)
    ip_private=$(ip -f inet -o addr show enp0s9 | cut -d\  -f 7 | cut -d/ -f 1)

    echo '====================================================================='
    echo ' Community Hass.io Add-ons: Vagrant'
    echo ''
    echo ' Hass.io is installed & started! It may take a couple of minutes'
    echo ' before it is actually responding/available.'
    echo ''
    echo ' Home Assitant is running on the following links:'
    echo "  - http://${ip_private}:8123"
    echo "  - http://${ip_public}:8123"
    echo ''
    echo ' Portainer is running on the following links:'
    echo "  - http://${ip_private}:9000"
    echo "  - http://${ip_public}:9000"
    echo ''
    echo ' Netdata is providing awesome stats on these links:'
    echo "  - http://${ip_private}:19999"
    echo "  - http://${ip_public}:19999"
    echo '====================================================================='
}

# ==============================================================================
# RUN LOGIC
# ------------------------------------------------------------------------------
main() {
    install_requirements
    install_docker
    install_netdata
    install_portainer
    install_hassio
    show_post_up_message
    exit "${EX_OK}"
}
main "$@"
