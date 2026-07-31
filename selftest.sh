#!/usr/bin/env bash
#
# selftest.sh — Autodiagnóstico del contenedor "mininet-in-a-container".
# Comprueba que todo lo necesario para las sesiones 1 y 2 del laboratorio
# está presente y funcionando. Ejecuta simplemente:  /selftest.sh
#
# Códigos de salida: 0 = todo OK, 1 = algún fallo.

# ----- Colores (se desactivan si no hay terminal) ----------------------------
if [ -t 1 ]; then
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
else
    GREEN=''; RED=''; YELLOW=''; BOLD=''; NC=''
fi

fail=0

ok()   { printf "  ${GREEN}[ OK ]${NC} %s\n" "$1"; }
bad()  { printf "  ${RED}[FAIL]${NC} %s\n" "$1"; fail=1; }
warn() { printf "  ${YELLOW}[WARN]${NC} %s\n" "$1"; }
head() { printf "\n${BOLD}%s${NC}\n" "$1"; }

# ----- 1. Comandos esenciales instalados -------------------------------------
head "1. Herramientas instaladas"
for cmd in mn ovs-vsctl ovs-testcontroller xterm wireshark tcpdump python3; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd encontrado"
    else
        bad "$cmd NO encontrado"
    fi
done

# python-tk (necesario para miniedit.py)
if python3 -c "import tkinter" >/dev/null 2>&1; then
    ok "python3-tk (tkinter) disponible"
else
    bad "python3-tk (tkinter) NO disponible — miniedit.py no funcionará"
fi

# ----- 2. Open vSwitch en marcha ---------------------------------------------
head "2. Open vSwitch"
if ovs-vsctl show >/dev/null 2>&1; then
    ok "ovsdb-server responde"
else
    bad "ovs-vsctl no puede hablar con ovsdb — ¿arrancó el servicio?"
    warn "Prueba:  /usr/share/openvswitch/scripts/ovs-ctl --system-id=random start"
fi

# ----- 3. Código fuente de Mininet -------------------------------------------
head "3. Mininet"
if [ -f /root/mininet/examples/miniedit.py ]; then
    ok "Repositorio de Mininet y miniedit.py presentes"
else
    bad "No se encuentra /root/mininet/examples/miniedit.py"
fi

# ----- 4. Reenvío X (DISPLAY) ------------------------------------------------
head "4. X Window System"
if [ -z "$DISPLAY" ]; then
    bad "La variable DISPLAY está vacía"
    warn "Exporta un valor, p.ej.:  export DISPLAY=:0  (Linux)  o  host.docker.internal:0 (macOS)"
else
    ok "DISPLAY=$DISPLAY"
    # Intento no bloqueante de contactar con el servidor X
    if command -v xset >/dev/null 2>&1; then
        if timeout 5 xset q >/dev/null 2>&1; then
            ok "Conexión con el servidor X correcta"
        else
            bad "No se puede abrir el display '$DISPLAY'"
            warn "En el HOST ejecuta:  xhost +local:   (Linux)"
            warn "o abre XQuartz y:     xhost + 127.0.0.1   (macOS)"
        fi
    else
        warn "xset no disponible; no se pudo comprobar la conexión X"
    fi
fi

# ----- Resumen ---------------------------------------------------------------
head "Resultado"
if [ "$fail" -eq 0 ]; then
    printf "  ${GREEN}${BOLD}Todo correcto: el contenedor está listo para el laboratorio.${NC}\n\n"
    exit 0
else
    printf "  ${RED}${BOLD}Se detectaron problemas. Revisa las líneas [FAIL] de arriba.${NC}\n\n"
    exit 1
fi
