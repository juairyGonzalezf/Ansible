#!/bin/bash
# Script para arrancar Managed Servers de WebLogic autogenerado por Ansible

SERVERS=$@
USER="{{ wls_user }}"
PASS="{{ wls_pass }}"
ADMIN_URL="t3://{{ inventory_hostname }}:7004"
DOMAIN_PATH="{{ wls_domain_path }}"

if [ -z "$1" ]; then
    echo "Error: Indica los servidores o 'all'"
    exit 1
fi

WLST_SCRIPT="/tmp/start_servers.py"

echo "connect('$USER','$PASS','$ADMIN_URL')" > $WLST_SCRIPT

if [ "$1" == "all" ]; then
    echo "print '--- Arrancando TODOS los Managed Servers ---'" >> $WLST_SCRIPT
    echo "server_list = cmo.getServers()" >> $WLST_SCRIPT
    echo "for server in server_list:" >> $WLST_SCRIPT
    echo "    name = server.getName()" >> $WLST_SCRIPT
    echo "    if name != 'AdminServer':" >> $WLST_SCRIPT
    echo "        print 'Intentando arrancar server: ' + name" >> $WLST_SCRIPT
    echo "        try:" >> $WLST_SCRIPT
    echo "            start(name, 'Server')" >> $WLST_SCRIPT
    echo "        except:" >> $WLST_SCRIPT
    echo "            print ' --> AVISO: ' + name + ' ya estaba arrancado o fallo al iniciar.'" >> $WLST_SCRIPT
else
    for server in $SERVERS; do
        echo "print 'Intentando arrancar server: $server'" >> $WLST_SCRIPT
        echo "try:" >> $WLST_SCRIPT
        echo "    start('$server', 'Server')" >> $WLST_SCRIPT
        echo "except:" >> $WLST_SCRIPT
        echo "    print ' --> AVISO: $server ya estaba arrancado o fallo al iniciar.'" >> $WLST_SCRIPT
    done
fi

echo "disconnect()" >> $WLST_SCRIPT
echo "exit()" >> $WLST_SCRIPT

# Ejecutar WLST
source $DOMAIN_PATH/bin/setDomainEnv.sh
java weblogic.WLST $WLST_SCRIPT

rm -f $WLST_SCRIPT
