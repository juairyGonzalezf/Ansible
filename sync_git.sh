#!/bin/bash

# 1. Ir al directorio (si falla, aborta el script)
cd /etc/ansible/ || exit 1

# 2. Añadir todos los cambios actuales al "Stage"
git add .

# 3. Comprobar si hay cambios y hacer commit ANTES del pull
# Si el comando diff-index falla (es decir, hay cambios), hacemos commit.
if ! git diff-index --quiet HEAD --; then
    git commit -m "Auto-sync: $(date +'%Y-%m-%d %H:%M:%S')"
    CAMBIOS_LOCALES=true
else
    CAMBIOS_LOCALES=false
fi

# 4. Ahora que el directorio está "limpio", sincronizamos (Pull + Rebase)
# Bajamos los cambios del remoto y aplicamos nuestros commits locales por encima
git pull  etc/ansible --rebase

# 5. Si hubo cambios locales, los subimos al servidor
if [ "$CAMBIOS_LOCALES" = true ]; then
    git push  etc/ansible
fi