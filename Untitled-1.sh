#!/bin/bash

BLUE='\e[1;34m'
NC='\e[0m' # No Color

set -euo pipefail

RAM="8192"
VLAN="300"
SERVEUR_TAP="148"
CLIENT_TAP="149"
MASTER_IMG_NAME="win11"
MASTER_IMG_NAME_SERVER="win22-server"
LAB_NAME="win_lab"

usage() {
>&2 cat << EOF
Usage: $0
   [ -v | --vlan <vlan id> ]
   [ -t | --SERVEUR-port <SERVEUR vm port number> ]
   [ -i | --CLIENT-port <CLIENT vm port number> ]
   [ -h | --help ]
EOF
exit 1
}

ARGS=$(getopt -a -o v:t:i:h --long vlan:,SERVEUR-port:,CLIENT-port:,help -- "$@")

eval set -- "${ARGS}"
while :
do
    case $1 in
        -v | --vlan)
            VLAN=$2
            shift 2
            ;;
        -t | --SERVEUR-port)
            SERVEUR_TAP=$2
            shift 2
            ;;
        -i | --CLIENT-port)
            CLIENT_TAP=$2

            shift 2
            ;;
        -h | --help)
            usage
            ;;
        # -- means the end of the arguments; drop this, and break out of the while loop
        --)
            shift
            break
            ;;
        *) >&2 echo Unsupported option: "$1"
           usage
           ;;
      esac
done

if [[ -z "$VLAN" ]] || [[ "$VLAN" =~ [^[:digit:]] ]]; then
    echo "VLAN identifier is required"
    usage
fi

if [[ -z "$SERVEUR_TAP" ]] || [[ "$SERVEUR_TAP" =~ [^[:digit:]] ]]; then
    echo "SERVEUR tap port number is required"
    usage
fi

if [[ -z "$CLIENT_TAP" ]] || [[ "$CLIENT_TAP" =~ [^[:digit:]] ]]; then
    echo "CLIENT tap port number is required"
    usage
fi

echo -e "~> NFS lab VLAN identifier: ${BLUE}${VLAN}${NC}"
echo -e "~> SERVEUR VM tap port number: ${BLUE}${SERVEUR_TAP}${NC}"
echo -e "~> CLIENT VM tap port number: ${BLUE}${CLIENT_TAP}${NC}"
tput sgr0

# Switch ports configuration
for p in ${SERVEUR_TAP} ${CLIENT_TAP}
do
    echo "Configuring tap${p} port..."
    sudo ovs-vsctl set port tap${p} tag=${VLAN} vlan_mode=access
done

# Copy  SERVEUR and CLIENT VMs image files
mkdir -p $HOME/vm/${LAB_NAME}

for f in SERVEUR_img CLIENT_img
do
    if [[ ! -f ${f}.qcow2 ]]; then
        echo "Copying ${f}.qcow2 image file..."
        cp $HOME/masters/${MASTER_IMG_NAME}.qcow2 $HOME/vm/${LAB_NAME}/${f}.qcow2
        cp $HOME/masters/${MASTER_IMG_NAME}.qcow2_OVMF_VARS.fd $HOME/vm/${LAB_NAME}/${f}.qcow2_OVMF_VARS.fd
    fi
done


cd $HOME/vm/${LAB_NAME}

for vm in SERVEUR CLIENT
do
    # Launch NFS SERVEUR VM
    tap=${vm^^}_TAP
    $HOME/vm/scripts/ovs-startup.sh ${vm}_img.qcow2 ${RAM} ${!tap}
done

exit 0