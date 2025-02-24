#!/bin/sh

# Verificar parámetros
if [ "$#" -ne 4 ]; then
    echo "Uso: $0 <VM_ORIGEN> <ESXI_DESTINO> <DATASTORE_DESTINO> <USUARIO_ESXI>"
    exit 1
fi

# Parámetros
VM_ORIGEN=$1
ESXI_DESTINO=$2
DATASTORE_DESTINO=$3
USUARIO_ESXI=$4
DATASTORE_ORIGEN="/vmfs/volumes/datastore1"
DEST_PATH="/vmfs/volumes/$DATASTORE_DESTINO/$VM_ORIGEN"

# Obtener IP del ESXi de origen
ESXI_ORIGEN=$(esxcli network ip interface ipv4 get | grep vmk0 | awk '{print $2}')

# Obtener ID de la VM origen
VM_ID=$(vim-cmd vmsvc/getallvms | grep -w "$VM_ORIGEN" | awk '{print $1}')

# Verificar si la VM existe
if [ -z "$VM_ID" ]; then
    echo "Error: La máquina virtual '$VM_ORIGEN' no existe en este host."
    exit 1
fi

# Apagar la VM si está encendida
POWER_STATE=$(vim-cmd vmsvc/power.getstate $VM_ID | tail -n 1)
if [ "$POWER_STATE" = "Powered on" ]; then
    echo "Apagando la VM '$VM_ORIGEN'..."
    vim-cmd vmsvc/power.off $VM_ID
fi

# Crear directorio en ESXi destino
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$ESXI_DESTINO "mkdir -p $DEST_PATH"

# Copiar archivos de la VM al servidor de destino
scp -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$DATASTORE_ORIGEN/$VM_ORIGEN"/* root@$ESXI_DESTINO:$DEST_PATH/


# Crear el directorio en el servidor de destino
#echo "Creando directorio en ESXi destino..."
#ssh $USUARIO_ESXI@$ESXI_DESTINO "mkdir -p $DEST_PATH"

# Copiar archivos de la VM al servidor de destino
#echo "Copiando archivos de la VM al nuevo servidor..."
#scp -r "$DATASTORE_ORIGEN/$VM_ORIGEN"/* $USUARIO_ESXI@$ESXI_DESTINO:$DEST_PATH/

# Registrar la VM en el ESXi destino
echo "Registrando la VM en ESXi destino..."
ssh $USUARIO_ESXI@$ESXI_DESTINO "vim-cmd solo/registervm $DEST_PATH/$VM_ORIGEN.vmx"

echo "✅ Proceso completado. La VM '$VM_ORIGEN' ha sido copiada a '$ESXI_DESTINO'."

