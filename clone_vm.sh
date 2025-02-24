#!/bin/sh

# Verificar parámetros
if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <VM_ORIGEN> <VM_CLONADA>"
    exit 1
fi

# Configuración
SOURCE_VM=$1
CLONE_VM=$2
DATASTORE="/vmfs/volumes/datastore1"

# Obtener el ID de la VM origen
VM_ID=$(vim-cmd vmsvc/getallvms | grep -w "$SOURCE_VM" | awk '{print $1}')

# Verificar si la VM origen existe
if [ -z "$VM_ID" ]; then
    echo "Error: La máquina virtual '$SOURCE_VM' no existe."
    exit 1
fi

# Apagar la VM si está encendida
POWER_STATE=$(vim-cmd vmsvc/power.getstate $VM_ID | tail -n 1)
if [ "$POWER_STATE" = "Powered on" ]; then
    echo "Apagando la VM origen..."
    vim-cmd vmsvc/power.off $VM_ID
fi

# Crear el directorio para la VM clonada
echo "Clonando la VM..."
mkdir "$DATASTORE/$CLONE_VM"
cp -r "$DATASTORE/$SOURCE_VM"/* "$DATASTORE/$CLONE_VM/"

# Renombrar el archivo .vmx
mv "$DATASTORE/$CLONE_VM/$SOURCE_VM.vmx" "$DATASTORE/$CLONE_VM/$CLONE_VM.vmx"

# Modificar el displayName en el .vmx
sed -i "s/displayName = \"$SOURCE_VM\"/displayName = \"$CLONE_VM\"/g" "$DATASTORE/$CLONE_VM/$CLONE_VM.vmx"

# Detectar discos en el .vmx y renombrarlos, ignorando CD/DVD
grep -E 'scsi|ide|sata' "$DATASTORE/$CLONE_VM/$CLONE_VM.vmx" | grep 'fileName' | awk -F'"' '{print $2}' | while read -r disk_file; do
    if [[ "$disk_file" == *"CD/DVD"* ]]; then
        echo "Ignorando dispositivo de CD/DVD: $disk_file"
        continue
    fi

    NEW_DISK_FILE=$(echo "$disk_file" | sed "s/$SOURCE_VM/$CLONE_VM/g")
    echo "Renombrando disco: $disk_file -> $NEW_DISK_FILE"

    # Renombrar archivos .vmdk
    if [ -f "$DATASTORE/$CLONE_VM/$disk_file" ]; then
        mv "$DATASTORE/$CLONE_VM/$disk_file" "$DATASTORE/$CLONE_VM/$NEW_DISK_FILE"
    fi

    # Modificar referencias en .vmx
    sed -i "s|$disk_file|$NEW_DISK_FILE|g" "$DATASTORE/$CLONE_VM/$CLONE_VM.vmx"

    # Modificar el contenido de los archivos .vmdk
    if [ -f "$DATASTORE/$CLONE_VM/$NEW_DISK_FILE" ]; then
        sed -i "s/$SOURCE_VM/$CLONE_VM/g" "$DATASTORE/$CLONE_VM/$NEW_DISK_FILE"
    fi

    # Si hay un archivo flat.vmdk, renombrarlo
    FLAT_DISK="${disk_file%.*}-flat.vmdk"
    NEW_FLAT_DISK="${NEW_DISK_FILE%.*}-flat.vmdk"
    if [ -f "$DATASTORE/$CLONE_VM/$FLAT_DISK" ]; then
        mv "$DATASTORE/$CLONE_VM/$FLAT_DISK" "$DATASTORE/$CLONE_VM/$NEW_FLAT_DISK"
    fi
done

# Verificar si la VM clonada ya está registrada
if vim-cmd vmsvc/getallvms | grep -q -w "$CLONE_VM"; then
    echo "La VM '$CLONE_VM' ya está registrada en ESXi. No es necesario registrarla nuevamente."
else
    echo "Registrando la VM '$CLONE_VM' en ESXi..."
    vim-cmd solo/registervm "$DATASTORE/$CLONE_VM/$CLONE_VM.vmx"
fi

echo "Clonación completada. La nueva VM '$CLONE_VM' está lista."

