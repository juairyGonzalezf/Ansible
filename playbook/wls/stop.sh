#!/bin/bash
# Script para parar Managed Servers de WebLogic autogenerado por Ansible

SERVERS=$@
USER="{{ wls_user }}"
PASS="{{ wls_pass }}"
ADMIN_URL="t3://{{ inventory_hostname }}:7004"
DOMAIN_PATH="{{ wls_domain_path }}"

if [ -z "$1" ]; then
    echo "Error: Indica los servidores o 'all'"
    exit 1
fi

WLST_SCRIPT="/tmp/stop_servers.py"

echo "connect('$USER','$PASS','$ADMIN_URL')" > $WLST_SCRIPT

if [ "$1" == "all" ]; then
    echo "print '--- Deteniendo TODOS los Managed Servers ---'" >> $WLST_SCRIPT
    echo "server_list = cmo.getServers()" >> $WLST_SCRIPT
    echo "for server in server_list:" >> $WLST_SCRIPT
    echo "    name = server.getName()" >> $WLST_SCRIPT
    echo "    if name != 'AdminServer':" >> $WLST_SCRIPT
    echo "        print 'Intentando parar server: ' + name" >> $WLST_SCRIPT
    echo "        try:" >> $WLST_SCRIPT
    echo "            shutdown(name, 'Server', ignoreSessions='true', force='true')" >> $WLST_SCRIPT
    echo "        except:" >> $WLST_SCRIPT
    echo "            print ' --> AVISO: ' + name + ' ya estaba parado o no se pudo apagar.'" >> $WLST_SCRIPT
else
    for server in $SERVERS; do
        echo "print 'Intentando parar server: $server'" >> $WLST_SCRIPT
        echo "try:" >> $WLST_SCRIPT
        echo "    shutdown('$server', 'Server', ignoreSessions='true', force='true')" >> $WLST_SCRIPT
        echo "except:" >> $WLST_SCRIPT
        echo "    print ' --> AVISO: $server ya estaba parado o no se pudo apagar.'" >> $WLST_SCRIPT
    done
fi

echo "disconnect()" >> $WLST_SCRIPT
echo "exit()" >> $WLST_SCRIPT

# Ejecutar WLST
source $DOMAIN_PATH/bin/setDomainEnv.sh
java weblogic.WLST $WLST_SCRIPT

rm -f $WLST_SCRIPT