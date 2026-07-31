#!/usr/bin/env bash
#
# Punto de entrada del contenedor Mininet.
# - Arranca Open vSwitch
# - Establece un DISPLAY por defecto si el usuario no lo pasó
# - Muestra pistas para el reenvío X si algo falla
# - Al salir del shell, para Open vSwitch limpiamente

# Nota: NO usamos "set -e". El arranque de Open vSwitch puede devolver errores
# no fatales (p.ej. el módulo de kernel no se puede insertar en kernels tipo
# linuxkit de Docker Desktop); esos errores no deben impedir llegar al shell.

# --- X Window: fallback de DISPLAY -------------------------------------------
# Si el usuario no exportó DISPLAY, asumimos el caso más común (macOS/XQuartz).
# En Linux normalmente DISPLAY ya viene como :0 desde el host.
export DISPLAY="${DISPLAY:-host.docker.internal:0}"

# --- Open vSwitch -------------------------------------------------------------
# En kernels tipo linuxkit (Docker Desktop) NO existe el módulo openvswitch, y
# "ovs-ctl start" se queda colgado intentando insertarlo: arranca ovsdb-server
# pero NO llega a lanzar ovs-vswitchd, con lo que cualquier "add-br" se cuelga.
# Por eso arrancamos los dos daemons a mano y forzamos el datapath en espacio
# de usuario (netdev), que no necesita módulo de kernel.
mkdir -p /var/run/openvswitch /etc/openvswitch /var/log/openvswitch

# Base de datos (solo se crea si no existe)
if [ ! -e /etc/openvswitch/conf.db ]; then
    ovsdb-tool create /etc/openvswitch/conf.db \
        /usr/share/openvswitch/vswitch.ovsschema
fi

# 1) ovsdb-server
ovsdb-server /etc/openvswitch/conf.db \
    --remote=punix:/var/run/openvswitch/db.sock \
    --remote=ptcp:6640 \
    --pidfile --detach --log-file 2>/dev/null || true

ovs-vsctl --no-wait init 2>/dev/null || true

# 2) ovs-vswitchd (el daemon que faltaba)
ovs-vswitchd --pidfile --detach --log-file 2>/dev/null || true

# Nota: el tipo de datapath (kernel vs netdev) lo decide Mininet al crear el
# puente, mediante el flag --switch. Para que "mn" use netdev sin escribir los
# flags cada vez, la imagen incluye el wrapper /usr/local/bin/mn-user (ver más
# abajo en el mensaje de ayuda).

# --- Mensajes de ayuda --------------------------------------------------------
echo
echo ">>> Open vSwitch arrancado (ovsdb-server + ovs-vswitchd)."
echo ">>> DISPLAY=$DISPLAY"
echo ">>> En Docker Desktop usa el datapath de espacio de usuario. Arranca Mininet con:"
echo ">>>     mn-user            (equivale a: mn --switch ovsk,datapath=user --controller ovsc)"
echo ">>>     mn-user -x         (con ventanas xterm)"
echo ">>> Si las ventanas X (xterm, wireshark) NO aparecen, ejecuta EN EL HOST:"
echo ">>>     Linux : xhost +local:"
echo ">>>     macOS : abre XQuartz y luego  xhost + 127.0.0.1"
echo ">>> Comprueba el entorno con:  /selftest.sh"
echo

# Shell interactivo del usuario
bash

# --- Limpieza al salir --------------------------------------------------------
ovs-appctl -t ovs-vswitchd exit 2>/dev/null || true
ovs-appctl -t ovsdb-server exit 2>/dev/null || true
