## Disclaimer

Using this tool to mount and modify NTFS devices carries the risk of data loss. It is recommended to back up important data before use. This tool is provided "as is" without any express or implied warranties. The developer is not responsible for any data loss caused by using this tool.

## System Requirements

This tool requires the following system dependencies:

1. **Swift (Xcode Command Line Tools)** - Apple's development tools
2. **Homebrew** - Package manager for macOS
3. **MacFUSE** - File system user space framework
4. **ntfs-3g** - NTFS file system driver

### Installing System Dependencies

Before first use, please check if the system dependencies are installed. In the "System Dependencies" tab, click the "Check Dependencies" button, and the system will automatically detect the installation status of required dependencies.

If missing dependencies are detected, please follow these steps to install them manually:

#### 1. Install Xcode Command Line Tools

Run the following command in Terminal:

```bash
xcode-select --install
```

An installation window will pop up after running. Follow the prompts to complete the installation. The installation process may take several minutes to tens of minutes, please wait patiently.

#### 2. Install Homebrew

Run the following command in Terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the prompts to complete the installation. If the network is slow, you can use a domestic mirror source:

```bash
/bin/bash -c "$(curl -fsSL https://gitee.com/ineo6/homebrew-install/raw/master/install.sh)"
```

#### 3. Install MacFUSE

Run the following command in Terminal:

```bash
brew install --cask macfuse
```

#### 4. Install ntfs-3g

Run the following command in Terminal:

```bash
brew tap gromgit/homebrew-fuse
brew install ntfs-3g-mac
```

**Note**: The installation order is important. Please install in the order: 1 → 2 → 3 → 4.

## Usage Steps

### Check System Dependencies

In the "System Dependencies" tab, click the "Check Dependencies" button, and the system will automatically detect the installation status of required dependencies. If missing dependencies are detected, detailed installation instructions will be displayed, including installation commands and descriptions.

### Manage NTFS Devices

After inserting an NTFS formatted removable storage device, you can view all connected devices in the "NTFS Devices" tab.

Device status is divided into two types:

- **Read-Only** - The device can only be read, not written. This is macOS's default handling of NTFS devices.
- **Read-Write** - The device is mounted in read-write mode and can read and write files normally.

### Mount Device as Read-Write Mode

For devices in read-only status, you can click the "Configure as Read-Write" button to mount them in read-write mode. This operation requires administrator privileges, and the system will pop up a password input dialog.

**Notes:**

- Mounting requires administrator privileges, please have your system password ready
- If mounting fails, possible reasons include:
  - The device file system is in a dirty state (if this NTFS device was previously used on a Windows computer with Fast Startup enabled, please plug it back into the Windows computer and fully shut down before trying again)
  - The device is being used by other programs
  - System permission issues
- Please safely eject the device after mounting to avoid data loss

### Unmount Device

For mounted devices, you can click the "Unmount" button to unmount them. Unmounting requires administrator privileges.

**Characteristics of Unmounting:**
- Removes the device from the file system
- The device remains physically connected to the computer
- The system may automatically remount the device (e.g., reinsertion or system auto-mount)
- The device remains in the list, marked as "Unmounted" status
- Can be remounted for use

**Use Cases:**
- Temporarily disconnect device access while the device remains connected to the computer
- Need to reconfigure device mounting method
- When device has issues, unmount first then remount

### Eject Device

For mounted devices, you can click the "Eject" button to completely disconnect them. Ejecting does not require administrator privileges.

**Characteristics of Ejecting:**
- Completely disconnects the device and removes it from the system
- The device will disappear from the list
- The system will not automatically remount the device
- Need to reinsert the device to use again
- Indicates that the device can be safely removed

**Use Cases:**
- Before removing the device, ensure data has been completely written
- Need to completely disconnect the device
- When the device is no longer needed
- Similar to the "Eject" function in macOS Finder

**Unmount vs Eject:**

| Feature | Unmount | Eject |
|---------|---------|-------|
| Requires Admin Privileges | ✅ Yes | ❌ No |
| Device Physical Connection | ✅ Remains Connected | ✅ Remains Connected |
| System Auto Remount | ⚠️ May | ❌ No |
| Device in List | ✅ Retained (marked as unmounted) | ❌ Removed |
| Can Remount | ✅ Yes | ❌ Need to reinsert |
| Use Cases | Temporary disconnect, reconfigure | Prepare to remove, completely disconnect |

## Frequently Asked Questions

### Why is my device showing as read-only?

This is macOS's default behavior. macOS mounts NTFS devices in read-only mode by default. This tool can mount devices in read-write mode.

### What to do if mounting fails?

If the mounting operation fails or times out, please check the following:

- **System Dependencies**: Ensure all system dependencies are installed (Xcode Command Line Tools, Homebrew, MacFUSE, ntfs-3g)
- **Administrator Privileges**: Ensure the administrator password entered is correct
- **File System State**: If this NTFS device was previously used on a Windows computer with Fast Startup enabled, the file system may be in a dirty state. Please plug it back into the Windows computer and fully shut down (not sleep/hibernate), then try mounting again
- **Device Usage**: Check if other programs are using the device, close related programs and try again
- **Operation Timeout**: If the operation times out, the application will automatically cancel the operation to prevent hanging. Please check the above reasons and try again

### What to do if dependency installation fails?

If you encounter problems during installation, please check the following:

- **Network Connection**: Ensure network connection is normal, installation requires downloading files
- **Disk Space**: Ensure sufficient disk space (Xcode Command Line Tools requires several GB of space)
- **System Permissions**: Ensure administrator privileges, some installations require password input
- **Installation Order**: Please install dependencies in the correct order (Xcode → Homebrew → MacFUSE → ntfs-3g)

**Common Issues:**

1. **Xcode Command Line Tools Installation Fails**
   - Check network connection
   - Try manually downloading the installer from Apple Developer website

2. **Homebrew Installation Slow or Fails**
   - Use domestic mirror source (see installation steps above)
   - Check network proxy settings

3. **MacFUSE or ntfs-3g Installation Fails**
   - Ensure Homebrew is installed first
   - Run `brew update` to update Homebrew
   - Check for permission issues

If the problem persists, please refer to the official documentation of each dependency or seek technical support.

### Cannot access device after unmounting?

After unmounting, the device will be removed from the system. If you need to access it again, please reinsert the device or use the system's built-in mounting function.

## Operation Logs

In the "Operation Logs" tab, you can view records of all operations, including:

- Dependency check results
- Device detection status
- Mount/unmount operation results
- Error messages and warnings

**Enable Operation Logs:**

Operation logs are disabled by default and need to be manually enabled. Check the "Enable Operation Logs" checkbox in the "Operation Logs" tab to enable logging. When enabled, the app will record all operation logs. When disabled, new logs will not be recorded, but previously recorded logs will still be retained.

**Log Storage:**

Logs are saved in JSON format to the file system at the following location:

```
~/Library/Application Support/Nigate/logs.json
```

The log file uses formatted JSON format and can be opened directly with a text editor for viewing. When you uninstall the app, the log file will not be automatically deleted, making it easy to view or backup later.

**Log Limits:**

To ensure application performance and stability, the logging system has the following limits:

- **Retention Period**: Logs are saved for a maximum of 30 days by default. Logs older than 30 days will be automatically cleaned up
- **Record Count Limit**: A maximum of 500 log entries are retained. When the limit is exceeded, the oldest entries are automatically deleted, keeping only the latest 500 entries
- **File Size Limit**: The log file has a maximum size of 500KB. When the limit is exceeded, old entries are automatically deleted to keep the file size within the limit
- **Display Limit**: The interface displays a maximum of 300 log entries (the latest 300) to improve rendering performance

**Log Management:**

- **Clear Logs**: Click the "Clear" button to clear all log records
- **Export Logs**: Click the "Export" button to export logs as a text file for backup or sharing

## More Troubleshooting

If you encounter other issues (such as "file damaged" warnings, device busy errors, driver conflicts, etc.), please refer to our [Troubleshooting Center](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/9), which contains detailed troubleshooting steps and solutions.
