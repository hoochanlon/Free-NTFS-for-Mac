# Nigate Help

## About and safety

Nigate is a native macOS app built with Swift and SwiftUI, requiring macOS 14 or later. It discovers NTFS partitions through macOS disk services and uses MacFUSE with `ntfs-3g` for read-write mounting.

Mounting, repairing, and formatting can affect disk data. Back up important files first; do not disconnect a drive or force-quit the app during transfers. `ntfsfix` handles only a limited set of NTFS issues and is not a replacement for Windows `chkdsk`.

The app does not disable Gatekeeper or change global security settings. When installing MacFUSE or a system extension, follow the prompts shown by macOS and verify that the installation source is trusted.

## First use and dependencies

1. Open **Dependencies** and select **Check Dependencies** to review macOS, Xcode Command Line Tools, Homebrew, MacFUSE, `ntfs-3g`, and optional `fswatch`.
2. Read-write mounting requires macOS 14 or later, MacFUSE, and `ntfs-3g`. The dependency list describes the purpose and requirement status of each other component.
3. Use **One-click Install** to start the installation flow in Terminal, or expand a dependency to view and copy its command for manual installation. Approve system extensions only as prompted by macOS.
4. After installation or approval, check dependencies again. NTFS read-write mounting and related actions are unavailable until MacFUSE and `ntfs-3g` are ready.

## Devices and operations

After connecting an NTFS drive, Nigate scans it and lists recognized volumes on **NTFS Devices**. Each card shows the volume name, device identifier, mount point, and available/total capacity. Select **Refresh** to scan again. The batch controls can mount, restore read-only mode, unmount, or eject eligible devices.

### Icon guide

- **Navigation**: the puzzle piece opens Dependencies, the drive opens NTFS Devices, the question mark opens Help, and the gear opens Settings.
- **Title bar**: the lightning bolt toggles automatic read-write mounting; the menu-bar/Dock symbol toggles menu bar mode; the coffee cup cycles sleep-prevention modes; long-press the shield for 3 seconds to toggle status protection; the power symbol quits, the information symbol opens About, and the sun/moon switches appearance.
- **Status dot**: green means devices are recognized and none are read-only; orange means a core dependency is missing or at least one volume is read-only; gray means no NTFS device is recognized.
- **Device actions**: the circular arrow refreshes; the pencil mounts read-write; the eye restores read-only; the eject symbol unmounts; the drive with an X ejects the device; the wrench and screwdriver repair; the text cursor renames; the internal drive formats; and the curved arrow resets. A device-card drive icon is green for read-write and orange for read-only. Action icons are accompanied by text labels.

- **Read-only**: Files can be read but not changed. Windows Fast Startup or hibernation can leave a filesystem in an unsafe state; fully shut Windows down before reconnecting the drive to your Mac.
- **Read-write mount**: Select **Read-Write** and authorize the administrator operation. Nigate unmounts the existing volume before mounting it through `ntfs-3g`. Close apps that are using the volume first.
- **Restore read-only**: Removes the read-write mount and asks macOS to mount the volume read-only. A manual choice temporarily prevents auto-mount from changing it back.
- **Unmount**: Removes the filesystem mount while leaving the device connected. Refresh the device list to mount it again.
- **Eject**: Asks macOS to eject the device. Wait for the system operation to succeed before disconnecting it. Close apps that are using the drive first.
- **Reset**: Intended for device-busy issues. Nigate unmounts the partition, runs `ntfsfix`, then attempts to mount it read-only. Administrator authorization is required, and repairs carry data risk.
- **Repair**: Runs `ntfsfix` for limited filesystem repairs, then attempts to restore the previous mount mode. If it fails, note the error and avoid repeated repair attempts on important data.
- **Rename**: Enter a new volume label. Nigate unmounts the device, updates the NTFS label and partition name, then restores the previous read-only or read-write mode. The name must contain 1–32 characters and cannot include `\\ / : * ? " < > |`. Do not transfer files during this operation.

### Unmount vs. eject

| Action | Filesystem mount | Device connection | Use again |
| --- | --- | --- | --- |
| Unmount | Removed | Remains connected | Refresh, then mount again |
| Eject | Removed with the device | System asked to disconnect it | Reconnect the device |

Unmounting is not the same as safely disconnecting a drive. Use **Eject** and wait for confirmation before unplugging.

## Formatting

Formatting erases every partition and all data on the entire disk. It cannot be undone. Nigate recreates the whole disk with a GPT partition map and an NTFS filesystem; it does not merely clear the selected volume. Back up first and verify the target drive and its capacity.

For safety, formatting is allowed only when macOS confirms that the target is an external physical whole disk, not the startup disk, and not internal, virtual, an image, or synthesized. Device, partition, and protocol information must be present and consistent. Missing, unknown, or conflicting information blocks formatting. Do not disconnect the drive, shut down, or force-quit the app while formatting.

## Automatic read-write mounting

The title-bar **Auto Read-Write** switch processes NTFS volumes that are **already mounted and currently read-only** when Nigate scans. Turning it on checks current devices immediately; later device changes and scans trigger further checks. Unmounted, already read-write, or unrecognized devices are not candidates.

After you manually restore read-only mode or use **Reset**, the device is marked as manually read-only for the current connection, so auto-mount will not immediately change it back. A later manual read-write mount clears that choice. Automatic mounting may request administrator authorization. Turn the title-bar switch off if you do not want volumes to change modes automatically.

## Sleep prevention and status protection

Click the title-bar coffee-cup icon to cycle through **Off → Prevent Sleep → Smart Prevent Sleep → Off**. Status protection locks this control along with Auto Read-Write and menu-bar mode.

- **Off**: Nigate does not prevent system sleep.
- **Prevent Sleep**: Continuously prevents idle sleep, including when the drive is idle. Use it for long-running work.
- **Smart Prevent Sleep**: Monitors mounted disks only. Sleep is prevented while disk activity is detected and allowed again about 20 seconds after activity stops. With no mounted disks, sleep is not continuously prevented.

Sleep prevention stops when the app quits. Long-press the title-bar shield for 3 seconds to enable or remove status protection. This helps prevent accidental changes; it does not protect disks from failure or data loss.

## Settings

The **Settings** page controls whether the administrator password is saved in macOS Keychain, launch at login, the startup page, interface language, menu-bar mode, icon tooltips, and appearance. The administrator password is stored in Keychain only when password saving is enabled. You can turn this off or delete the saved password at any time.

Menu-bar mode hides the Dock icon while keeping the menu-bar entry available. Language and appearance choices are saved automatically. Auto Read-Write and sleep prevention can also be controlled from the title bar.

## Troubleshooting

### Why is my volume read-only?

macOS mounts NTFS read-only by default. Make sure MacFUSE and `ntfs-3g` are ready on the Dependencies page, then select **Read-Write**. If Windows Fast Startup or hibernation was used, reconnect the drive to Windows and fully shut it down first.

### Mount fails or times out

Recheck dependencies, close other apps using the drive, and verify administrator authorization. An unclean Windows shutdown can also leave the filesystem inconsistent. After a timeout, refresh the device list before trying again; do not repeatedly retry during file transfers.

### `Resource busy` error

Close Finder windows and apps using the volume, then select **Reset** on the device card. Nigate unmounts the partition, runs `ntfsfix`, and attempts a read-only remount. Administrator authorization is required. Back up important data first. If it still fails, record the error and seek support rather than running destructive terminal commands against an uncertain disk identifier.

### Repair did not restore read-write access

`ntfsfix` has limited capabilities and may repair only some metadata. Check the drive in Windows with administrator privileges using `chkdsk`. If important data is inaccessible, stop writing to the drive and prioritize data recovery.

### MacFUSE is outdated or its extension is blocked after a macOS update

Expand MacFUSE on the Dependencies page and follow the upgrade steps there. Approve the verified extension under **System Settings → Privacy & Security**. Labels vary by macOS release. Do not leave Gatekeeper disabled; if a documented step requires a temporary security change, follow its warning and restore the setting immediately afterward.

### Where is my device after unmounting?

Unmounting only removes the filesystem mount; the device remains connected. Refresh the device list to mount it again. Use **Eject** before disconnecting it.

For more help, see the [troubleshooting center](https://github.com/hoochanlon/Free-NTFS-for-Mac/issues/9). When reporting an issue, include the macOS version, device details, operation, and full error message; never include passwords or personal file contents.
