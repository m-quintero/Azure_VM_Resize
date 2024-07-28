# Script Name: az_vm_resize.sh
# Author: michael.quintero@rackspace.com
# Description: This script will resize an Azure (VM). It can create a manual backup before resizing, verify the desired size is valid, check for ongoing backup operations, & provide a final confirmation prior to the resize operation.

#!/bin/bash

prompt() {
    local prompt_text="$1"
    local input_variable_name="$2"
    read -p "$prompt_text: " input_value
    eval $input_variable_name="'$input_value'"
}

prompt "Enter your Azure subscription ID" subscription_id
prompt "Enter the resource group name" resource_group
prompt "Enter the VM name" vm_name

az account set --subscription "$subscription_id"

# Current size of the vm is set here
get_current_size() {
    az vm show --resource-group "$resource_group" --name "$vm_name" --query "hardwareProfile.vmSize" -o tsv
}

# Checks available sizes for the VM's region and current size family, which can be a deal breaker. Be realistic & informed when chosing the new size
get_available_sizes() {
    az vm list-sizes --location $(az vm show --resource-group "$resource_group" --name "$vm_name" --query "location" -o tsv) --query "[].name" -o tsv
}

# Grab backup vault and backup policy names. Still a work in progress as I'm ironing out kinks
get_backup_info() {
    local resource_group="$1"
    local vm_name="$2"
    local vm_id=$(az vm show --resource-group "$resource_group" --name "$vm_name" --query "id" -o tsv)
    local backup_vault=$(az backup vault list --query "[?contains(protectedItems, '$vm_id')].name" -o tsv)
    local backup_policy=$(az backup policy list --vault-name "$backup_vault" --query "[?contains(protectedItems, '$vm_id')].name" -o tsv)
    echo "$backup_vault,$backup_policy"
}

# Will not proceed if there is a backup in progress, so here we check and exit out if so
is_backup_in_progress() {
    local resource_group="$1"
    local backup_vault="$2"
    local vm_name="$3"
    local backup_jobs=$(az backup job list --resource-group "$resource_group" --vault-name "$backup_vault" --query "[?contains(backupManagementType, 'AzureIaasVM') && contains(entityFriendlyName, '$vm_name') && (contains(status, 'InProgress') || contains(status, 'TransferToVault'))]" -o tsv)
    if [ -n "$backup_jobs" ]; then
        echo "true"
    else
        echo "false"
    fi
}

current_size=$(get_current_size)
echo "Current VM size: $current_size"

available_sizes=$(get_available_sizes)
echo "Available sizes: $available_sizes"

prompt "Enter the desired VM size" new_size

# Super Importante! Check if the user's requested size is in the list of available sizes for this instance type
if echo "$available_sizes" | grep -w "$new_size" > /dev/null; then
    echo "Resizing to $new_size is possible. Proceeding..."
else
    echo "Error: $new_size is not a valid size in the current VM's region. Please choose a valid size."
    exit 1
fi

prompt "Do you want to create a manual backup before resizing? (yes/no)" create_backup

if [ "$create_backup" == "yes" ]; then
    # Getting those backup vault & backup policy names, but still a WIP as there could be issues under a tenant where a subscription has multiple subs
    IFS=',' read -r backup_vault backup_policy <<< "$(get_backup_info "$resource_group" "$vm_name")"
    if [ -z "$backup_vault" ] || [ -z "$backup_policy" ]; then
        echo "Error: Could not find backup vault or policy for the VM."
        exit 1
    fi

    backup_name="${vm_name}-backup-$(date +%Y%m%d%H%M%S)"
    echo "Creating manual backup with name $backup_name..."
    az backup protection backup-now --resource-group "$resource_group" --vault-name "$backup_vault" --item-name "$vm_name" --backup-management-type AzureIaasVM --policy-name "$backup_policy" --retain-until $(date -d "+30 days" +%Y-%m-%d) --name "$backup_name"
    echo "Manual backup created."
fi

# Like M$ does...a final confirmation before the resize process
prompt "Are you sure you want to proceed with stopping and resizing the VM? This will cause downtime. (yes/no)" confirm_resize

if [ "$confirm_resize" != "yes" ]; then
    echo "Resize operation aborted by the user."
    exit 1
fi

# Check if a backup is in progress
IFS=',' read -r backup_vault backup_policy <<< "$(get_backup_info "$resource_group" "$vm_name")"
if [ "$(is_backup_in_progress "$resource_group" "$backup_vault" "$vm_name")" == "true" ]; then
    echo "A backup is currently in progress. Please wait for the backup to complete before resizing the VM."
    exit 1
fi

# Start timing the downtime
start_time=$(date +%s)

echo "Stopping the VM..."
az vm deallocate --resource-group "$resource_group" --name "$vm_name"
echo "VM stopped."

echo "Resizing the VM to $new_size..."
az vm resize --resource-group "$resource_group" --name "$vm_name" --size "$new_size"
echo "VM resized."

echo "Starting the VM..."
az vm start --resource-group "$resource_group" --name "$vm_name"
echo "VM started."

# End timing the downtime
end_time=$(date +%s)
downtime=$((end_time - start_time))

# Convert downtime to minutes and seconds
minutes=$((downtime / 60))
seconds=$((downtime % 60))

# Display the downtime. I wanted to do this as I may run several at a time and would like to keep count of time spent on the operation
echo "The VM was down for $minutes minutes and $seconds seconds."

# Verifying the new VM size! Going to make this more robust here soon
updated_size=$(get_current_size)
echo "Updated VM size: $updated_size"

# Check if the resize was successful
if [ "$updated_size" == "$new_size" ]; then
    echo "The VM has been successfully resized to $new_size."
else
    echo "Failed to resize the VM. It is still $updated_size."
fi
