#!/bin/sh

# Rutas a los scripts
LOCAL_SCRIPT="/vmfs/volumes/datastore1/scripts/clone_vm.sh"
REMOTE_SCRIPT="/vmfs/volumes/datastore1/scripts/remote_clon.sh"
RENAME_SCRIPT="/vmfs/volumes/datastore1/scripts/rename_vm.sh"

# Función para mostrar las VMs disponibles en ESXi
listar_vms() {
    echo "🔍 Obteniendo lista de máquinas virtuales disponibles..."
    vim-cmd vmsvc/getallvms | awk 'NR>1 {print NR-1") "$2}'  
}

# Función para seleccionar una VM
seleccionar_vm() {
    listar_vms
    echo "🖥️  Ingresa el número de la VM a clonar:"
    read VM_NUM
    VM_NAME=$(vim-cmd vmsvc/getallvms | awk 'NR>1 {print NR-1" "$2}' | grep "^$VM_NUM " | awk '{print $2}')

    if [ -z "$VM_NAME" ]; then
        echo "❌ Opción inválida. Saliendo..."
        exit 1
    fi

    echo "✅ Has seleccionado: $VM_NAME"
}

# Menú de opciones
echo "====================================="
echo "     🖥️  SISTEMA DE CLONACIÓN DE VM"
echo "====================================="
echo "1) Clonar VM en este servidor (Local)"
echo "2) Copiar VM a otro servidor (Remoto)"
echo "3) Renombrar VM (Local)"
echo "4) Salir"
echo "====================================="
echo "Selecciona una opción:"
read OPCION

case $OPCION in
    1)
        seleccionar_vm
        echo "🖥️  Nombre para la nueva VM clonada:"
        read NEW_VM_NAME
        sh $LOCAL_SCRIPT "$VM_NAME" "$NEW_VM_NAME"
        ;;
    2)
        seleccionar_vm
        echo "🌍 IP del servidor ESXi destino:"
        read ESXI_DESTINO
        echo "📂 Nombre del datastore en ESXi destino (generalmente datastore1):"
        read DATASTORE_DESTINO
        echo "👤 Usuario de ESXi destino:"
        read USUARIO_ESXI
        sh $REMOTE_SCRIPT "$VM_NAME" "$ESXI_DESTINO" "$DATASTORE_DESTINO" "$USUARIO_ESXI"
        ;;
    3)
        seleccionar_vm
        echo "🖥️  Nombre para la nueva VM clonada:"
        read NEW_VM_NAME
        sh $RENAME_SCRIPT "$VM_NAME" "$NEW_VM_NAME"
        ;;
    4)
        echo "👋 Saliendo..."
        exit 0
        ;;
    *)
        echo "❌ Opción inválida. Saliendo..."
        exit 1
        ;;
esac

