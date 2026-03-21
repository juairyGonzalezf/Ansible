#!/bin/bash

if [ -z "$1" ]; then
  echo "Uso: $0 <Servidor1> [Servidor2] [Servidor3] ..."
  echo "Ejemplo: $0 FAM1 PMT1 TEST"
  exit 1
fi

SERVIDORES=$(IFS=, ; echo "$*")

ADMIN_URL="t3://su1168.corpo.ad.diba.es:7004"
ADMIN_USER="wls_admin"
ADMIN_PASS="WR;n1ZCeMe"

. /disc2/bea/INT-SAJ14/bin/setDomainEnv.sh

echo "====================================================="
echo " Preparando reinicio en PARALELO para: $SERVIDORES"
echo "====================================================="

TMP_SCRIPT="/tmp/wlst_restart_parallel_$$.py"

cat <<EOF > "$TMP_SCRIPT"
import java.lang.Thread as Thread

try:
    print "Conectando al AdminServer..."
    connect('$ADMIN_USER', '$ADMIN_PASS', '$ADMIN_URL')
    
    lista_servidores = "$SERVIDORES".split(",")
    lista_limpia = []
    for srv in lista_servidores:
        lista_limpia.append(srv.strip())
    
    print "\n=== FASE 1: APAGANDO EN PARALELO ==="
    for srv in lista_limpia:
        try:
            print ">> Enviando orden de apagado a " + srv + "..."
            shutdown(srv, 'Server', ignoreSessions='true', force='true', block='false')
        except Exception, e:
            pass

    print "\n>> Esperando a que todos se detengan por completo..."
    
    # Pasamos al arbol de monitorizacion en tiempo real
    domainRuntime()
    
    for srv in lista_limpia:
        estado = ""
        while estado != "SHUTDOWN" and estado != "UNKNOWN":
            try:
                # Consultamos el estado real en silencio
                slcr = getMBean('/ServerLifeCycleRuntimes/' + srv)
                if slcr != None:
                    estado = slcr.getState()
                else:
                    estado = "UNKNOWN"
            except:
                estado = "UNKNOWN"
                
            if estado != "SHUTDOWN" and estado != "UNKNOWN":
                Thread.sleep(3000)
        print ">> [OK] " + srv + " esta SHUTDOWN."

    print "\n=== FASE 2: ARRANCANDO EN PARALELO ==="
    
    # Volvemos a la raiz para lanzar los arranques
    domainConfig()
    
    for srv in lista_limpia:
        try:
            print ">> Enviando orden de arranque a " + srv + "..."
            start(srv, 'Server', block='false')
        except Exception, e:
            print ">> Error al intentar arrancar " + srv

    print "\n>> Esperando a que todos esten listos..."
    
    domainRuntime()
    for srv in lista_limpia:
        estado = ""
        while estado != "RUNNING":
            try:
                slcr = getMBean('/ServerLifeCycleRuntimes/' + srv)
                if slcr != None:
                    estado = slcr.getState()
                else:
                    estado = "UNKNOWN"
            except:
                estado = "UNKNOWN"
                
            if estado != "RUNNING":
                if estado == "FAILED_NOT_RESTARTABLE" or estado == "ADMIN":
                    print ">> [ADVERTENCIA] " + srv + " se ha quedado en estado " + estado
                    break
                Thread.sleep(3000)
        if estado == "RUNNING":
            print ">> [OK] " + srv + " esta RUNNING."

    print "\n====================================================="
    print " Reinicio asincrono completado con exito."
    print "====================================================="
    
    disconnect()
    exit()
    
except Exception, e:
    print "Se ha producido un error grave."
    print e
    disconnect()
    exit()
EOF

java weblogic.WLST "$TMP_SCRIPT"
rm -f "$TMP_SCRIPT"
