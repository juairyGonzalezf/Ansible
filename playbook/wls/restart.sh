#!/bin/bash
# Script para reiniciar Managed Servers de WebLogic autogenerado por Ansible

SERVERS="$*"
USER="{{ wls_user }}"
PASS="{{ wls_pass }}"
ADMIN_URL="t3://{{ inventory_hostname }}:7004"
DOMAIN_PATH="{{ wls_domain_path }}"

if [ -z "$1" ]; then
  echo "Error: Indica los servidores o 'all'"
  exit 1
fi

. $DOMAIN_PATH/bin/setDomainEnv.sh

echo "====================================================="
echo " Preparando reinicio en PARALELO para: $SERVERS"
echo "====================================================="

TMP_SCRIPT="/tmp/wlst_restart_parallel_$$.py"

cat <<EOF > "$TMP_SCRIPT"
import java.lang.Thread as Thread

try:
    print "Conectando al AdminServer..."
    connect('$USER', '$PASS', '$ADMIN_URL')
    
    lista_limpia = []
    
    # --- LOGICA PARA LA PALABRA 'all' ---
    if "$1" == "all":
        print "--- Detectado parametro 'all'. Obteniendo todos los Managed Servers ---"
        server_list = cmo.getServers()
        for server in server_list:
            name = server.getName()
            if name != 'AdminServer':
                lista_limpia.append(name)
    else:
        # Si no es all, usamos los argumentos separados por espacios que manda Ansible
        lista_argumentos = "$SERVERS".split()
        for srv in lista_argumentos:
            lista_limpia.append(srv.strip())
    
    print "\n=== FASE 1: APAGANDO EN PARALELO ==="
    for srv in lista_limpia:
        try:
            print ">> Enviando orden de apagado a " + srv + "..."
            shutdown(srv, 'Server', ignoreSessions='true', force='true', block='false')
        except Exception, e:
            print " --> AVISO: " + srv + " ya estaba parado o fallo al detenerse."

    print "\n>> Esperando a que todos se detengan por completo..."
    
    domainRuntime()
    for srv in lista_limpia:
        estado = ""
        while estado != "SHUTDOWN" and estado != "UNKNOWN":
            try:
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