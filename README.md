# Azure VM Resize Script

Here we have a cool little bash script which resizes an Azure (VM). It can create a manual backup before resizing, verify the desired size is valid, check for ongoing backup operations, & provide a final confirmation prior to the resize operation.

## Prerequisites

Before running the script, ensure the following prerequisites are met:

1. **Azure CLI**: Install Azure CLI from [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).
2. **Bash Shell**: Ensure you have a Bash env (available on Linux, macOS, & Windows with WSL).
3. **Azure Account**: An Azure account with permissions to manage VMs and backup resources.
4. **Permissions**: Permissions to execute `az account set`, `az vm show`, `az vm list-sizes`, `az backup vault list`, `az backup policy list`, `az backup job list`, `az vm deallocate`, `az vm resize`, and `az vm start` commands.

## Installation

### Azure CLI Installation

#### On Windows
Download and install from the link: [Azure CLI for Windows](https://aka.ms/installazurecliwindows)

#### On macOS
Use Homebrew to install Azure CLI:
```bash
brew update && brew install azure-cli
```

#### On Linux
Use the package manager of your distribution to install Azure CLI:
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Log in to Azure
Use the Azure CLI to log in to your Azure account:
```bash
az login
```

Ensure the Azure CLI is logged in and has the necessary permissions to manage resources:
```bash
az account set --subscription YOUR_SUBSCRIPTION_ID
```

Verify the installation by running:
```bash
az --version
```

## Usage

1. **Save the Script**: Save the script to a file, for example, `az_vm_resize.sh`.
2. **Make the Script Executable**: Run the following command to make the script executable:
   ```bash
   chmod +x az_vm_resize.sh
   ```
3. **Run the Script**: Execute the script by running:
   ```bash
   ./az_vm_resize.sh
   ```

### Script Workflow

1. **Prompts for Input**: The script will prompt you for your Azure subscription ID, resource group name, VM name, and the desired VM size.
2. **Validate Desired Size**: The script checks if the desired size is a valid option in the current VM's region.
3. **Optional Manual Backup**: The script prompts you to create a manual backup before resizing the VM.
4. **Check Backup Status**: The script checks if any backup operation is currently in progress.
5. **Final Confirmation**: The script asks for a final confirmation before stopping and resizing the VM.
6. **Perform Resize**: The script stops the VM, resizes it, and then starts it again, timing the downtime.
7. **Verify Resize**: The script verifies if the resize operation was successful.

### Example Run
```bash
./az_vm_resize.sh
```

### Output
The script will display the current VM size, available sizes, and prompts for the new size and backup options. It will also show the downtime duration and the final VM size after the resize operation.

## Notes

- **Downtime**: Stopping and resizing the VM will cause downtime. Make sure to perform these actions during a maintenance window or when it least impacts your operations.
- **Quota Check**: Ensure your subscription has the quota to support the new VM size.
- **Compatibility**: Check that the new VM size is available in the region where your VM is deployed.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author
Michael Quintero (michael.quintero@rackspace.com or michael.quintero@gmail.com)
