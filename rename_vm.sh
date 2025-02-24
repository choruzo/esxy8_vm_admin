#!/bin/sh

# Verificar parámetros
if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <VM_ANTIGUA> <VM_NUEVA>"
    exit 1
fi

# Configuración
OLD_VM=$1
NEW_VM=$2
DATASTORE="/vmfs/volumes/datastore1"
OLD_PATH="$DATASTORE/$OLD_VM"
NEW_PATH="$DATASTORE/$NEW_VM"

# Verificar si la VM antigua existe
if [ ! -d "$OLD_PATH" ]; then
    echo "❌ Error: La máquina virtual '$OLD_VM' no existe en $DATASTORE."
    exit 1
fi

# Renombrar el directorio de la VM
echo "🔄 Renombrando directorio de la VM..."
mv "$OLD_PATH" "$NEW_PATH"

# Renombrar el archivo .vmx
if [ -f "$NEW_PATH/$OLD_VM.vmx" ]; then
    echo "🔄 Renombrando archivo .vmx..."
    mv "$NEW_PATH/$OLD_VM.vmx" "$NEW_PATH/$NEW_VM.vmx"
else
    echo "⚠️ Advertencia: No se encontró el archivo .vmx en $NEW_PATH."
fi

# Modificar el .vmx para reflejar el nuevo nombre
echo "📝 Actualizando configuración en .vmx..."
sed -i "s/displayName = \"$OLD_VM\"/displayName = \"$NEW_VM\"/g" "$NEW_PATH/$NEW_VM.vmx"

# Renombrar y actualizar archivos de discos .vmdk
for DISK_FILE in "$NEW_PATH"/*.vmdk; do
    if [ -f "$DISK_FILE" ]; then
        NEW_DISK_FILE=$(echo "$DISK_FILE" | sed "s/$OLD_VM/$NEW_VM/g")
        echo "🔄 Renombrando disco: $(basename "$DISK_FILE") -> $(basename "$NEW_DISK_FILE")"
        mv "$DISK_FILE" "$NEW_DISK_FILE"

        # Modificar referencias dentro del .vmdk
        sed -i "s/$OLD_VM/$NEW_VM/g" "$NEW_DISK_FILE"
    fi
done

# Renombrar archivos .flat.vmdk si existen
for FLAT_DISK in "$NEW_PATH"/*-flat.vmdk; do
    if [ -f "$FLAT_DISK" ]; then
        NEW_FLAT_DISK=$(echo "$FLAT_DISK" | sed "s/$OLD_VM/$NEW_VM/g")
        echo "🔄 Renombrando disco plano: $(basename "$FLAT_DISK") -> $(basename "$NEW_FLAT_DISK")"
        mv "$FLAT_DISK" "$NEW_FLAT_DISK"
    fi
done

# Registrar la nueva VM en ESXi
echo "🖥️ Registrando la nueva VM en ESXi..."
vim-cmd solo/registervm "$NEW_PATH/$NEW_VM.vmx"

echo "✅ Proceso completado. La VM '$OLD_VM' ha sido renombrada a '$NEW_VM'."

