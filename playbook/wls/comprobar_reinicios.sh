#!/bin/bash

ADMIN_URL="t3://su1168.corpo.ad.diba.es:7004"
ADMIN_USER="wls_admin"
ADMIN_PASS="WR;n1ZCeMe"

# Cargar el entorno de WebLogic
. /disc2/bea/INT-SAJ14/bin/setDomainEnv.sh > /dev/null 2>&1

echo "====================================================="
echo " Consultando servidores que necesitan reinicio..."
echo "====================================================="

# Archivo temporal de Python (WLST)
TMP_SCRIPT="/tmp/wlst_check_restart_$$.py"

cat <<EOF > "$TMP_SCRIPT"
try:
    connect('$ADMIN_USER', '$ADMIN_PASS', '$ADMIN_URL')
    
    # 1. Sacamos la lista de servidores de la configuracion
    serverConfig()
    servidores = cmo.getServers()
    
    necesitan_reinicio = []
    
    # 2. Pasamos a ejecucion (Runtime) para ver su estado actual
    domainRuntime()
    
    for srv in servidores:
        nombre = srv.getName()
        try:
            # Buscamos el MBean de Runtime del servidor (solo existe si esta encendido)
            mbean_runtime = getMBean('/ServerRuntimes/' + nombre)
            if mbean_runtime != None:
                # Comprobamos el flag silenciosamente
                if mbean_runtime.isRestartRequired():
                    necesitan_reinicio.append(nombre)
        except Exception, e:
            # Si el servidor esta apagado o no responde, lo saltamos
            pass
            
    print "\n================ RESULTADO ================"
    if len(necesitan_reinicio) > 0:
        print "Los siguientes servidores NECESITAN ser reiniciados para aplicar cambios:"
        for nombre in necesitan_reinicio:
            print " -> " + nombre
        
        # Construimos el comando para facilitarte la vida
        comando = "./reiniciar.sh " + " ".join(necesitan_reinicio)
        print "\n(Puedes reiniciarlos ejecutando: " + comando + " )"
    else:
        print "Todo en orden. NINGUN servidor necesita reinicio en este momento."
    print "===========================================\n"
    
    disconnect()
    exit()
    
except Exception, e:
    print "Error al consultar el estado de los servidores."
    print e
    disconnect()
    exit()
EOF

# Ejecutar el archivo con WLST limpiando la salida
java weblogic.WLST "$TMP_SCRIPT" | grep -v "Initializing WebLogic Scripting Tool" | grep -v "Welcome to WebLogic Server" | grep -v "Type help()" | grep -v "Connecting to t3://" | grep -v "Successfully connected to Admin Server" | grep -v "Warning: An insecure protocol" | grep -v "To ensure on-the-wire security" | grep -v "Location changed to domainRuntime" | grep -v "For more help, use help" | grep -v "Location changed to serverConfig"

# Borrar el archivo temporal
rm -f "$TMP_SCRIPT"
