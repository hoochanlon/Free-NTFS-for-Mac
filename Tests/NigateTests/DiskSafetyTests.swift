import XCTest
@testable import Nigate
import NigateFSKitCore

final class DiskSafetyTests: XCTestCase {
    func testPartitionAndWholeDiskBoundaries() {
        XCTAssertTrue(DiskSafety.isPartition("/dev/disk4s2"))
        XCTAssertFalse(DiskSafety.isPartition("/dev/disk4"))
        XCTAssertTrue(DiskSafety.isWholeDisk("/dev/disk4"))
        XCTAssertFalse(DiskSafety.isWholeDisk("/dev/disk4s2"))
        XCTAssertTrue(DiskSafety.isMountableNode("/dev/disk4s2"))
        XCTAssertTrue(DiskSafety.isMountableNode("/dev/disk8"))
        XCTAssertFalse(DiskSafety.isMountableNode("/dev/rdisk8"))
        XCTAssertFalse(DiskSafety.isMountableNode("/dev/disk8s1s1"))
        XCTAssertEqual(DiskSafety.parentDiskPath("/dev/disk4s2"), "/dev/disk4")
        XCTAssertEqual(DiskSafety.parentDiskPath("/dev/disk8"), "/dev/disk8")
    }

    func testWholeDiskVolumeIdentifierFromDiskutilList() {
        XCTAssertEqual(
            DiskSafety.wholeDiskVolumeIdentifier(
                inListRow: "0:               Windows_NTFS 移动临时存储            *32.0 GB    disk8"
            ),
            "disk8"
        )
        XCTAssertEqual(
            DiskSafety.wholeDiskVolumeIdentifier(
                inListRow: "0:      NTFS                     Untitled             16.0 GB    disk12"
            ),
            "disk12"
        )
        XCTAssertNil(
            DiskSafety.wholeDiskVolumeIdentifier(
                inListRow: "0:     FDisk_partition_scheme                        *32.0 GB    disk8"
            )
        )
        XCTAssertNil(
            DiskSafety.wholeDiskVolumeIdentifier(
                inListRow: "0:      GUID_partition_scheme                        *500.1 GB   disk0"
            )
        )
        XCTAssertNil(
            DiskSafety.wholeDiskVolumeIdentifier(
                inListRow: "1:               Windows_NTFS SanDisk 32G            32.0 GB    disk4s2"
            )
        )
        XCTAssertNil(
            DiskSafety.wholeDiskVolumeIdentifier(
                inListRow: "2:                 Apple_APFS Container disk3         500 GB     disk0s2"
            )
        )
    }

    func testNTFSFilesystemRecognizesFilesystemIdentityWithoutPartitionTypeFalsePositives() {
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("File System Personality: xntfs"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("File System Personality: Unknown (xntfs)"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("Format: Unknown (xntfs)"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("格式: 未知 (xntfs)"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("File System Personality: NTFS"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("Type (Bundle): ntfs-3g"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("Format: NTFS-3g (macFUSE)"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("/dev/disk4s2 on /Volumes/Backup (xntfs, local, read-only)"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("/dev/disk8 on /Volumes/移动临时存储 (ntfs, local, read-only)"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("/dev/disk8 on /Volumes/移动临时存储 (xntfs, local, read-only)"))
        XCTAssertFalse(DiskSafety.isNTFSFilesystem("Partition Type: Windows_NTFS"))
        XCTAssertFalse(DiskSafety.isNTFSFilesystem("Volume Name: Unknown (xntfs)"))
        XCTAssertFalse(DiskSafety.isNTFSFilesystem("卷名: 未知 (xntfs)"))
        XCTAssertFalse(DiskSafety.isNTFSFilesystem("File System Personality: Unknown (exFAT)"))
        XCTAssertFalse(DiskSafety.isNTFSFilesystem("Volume Name: My NTFS Backup"))
        XCTAssertFalse(DiskSafety.isNTFSFilesystem("File System Personality: exFAT"))
    }

    func testNTFSVolumeInfoRequiresFilesystemIdentity() {
        let ventoy = """
        Device Identifier:        disk5s1
        Volume Name:              Ventoy
        File System Personality:  ExFAT
        Type (Bundle):            exfat
        Partition Type:           Windows_NTFS
        """
        XCTAssertFalse(DiskSafety.isNTFSVolumeInfo(ventoy))

        let plainNTFS = """
        Device Identifier:        disk4s1
        File System Personality:  NTFS
        Partition Type:           Microsoft Basic Data
        """
        XCTAssertTrue(DiskSafety.isNTFSVolumeInfo(plainNTFS))

        let xntfs = """
        Device Identifier:        disk4s1
        File System Personality:  Unknown (xntfs)
        Partition Type:           Microsoft Basic Data
        """
        let ntfs3g = """
        Device Identifier:        disk4s2
        Format:                   NTFS-3g (macFUSE)
        Partition Type:           Microsoft Basic Data
        """
        XCTAssertTrue(DiskSafety.isNTFSVolumeInfo(ntfs3g))
        XCTAssertTrue(DiskSafety.isNTFSVolumeInfo(xntfs))
    }

    func testKnownNTFSVolumeRequiresMatchingDeviceAndUUID() {
        let known = NTFSDevice(
            disk: "disk4s2",
            devicePath: "/dev/disk4s2",
            volume: "",
            volumeName: "Backup",
            volumeUuid: "volume-uuid",
            partitionUuid: "partition-uuid",
            isReadOnly: true,
            options: "",
            isMounted: false,
            isUnmounted: true,
            canFormat: false,
            capacity: nil
        )
        let sameVolume = """
        Device Identifier:        disk4s2
        Volume UUID:              volume-uuid
        File System Personality:  Unknown
        """
        let changedVolume = sameVolume.replacingOccurrences(of: "volume-uuid", with: "different-uuid")
        let missingUUID = """
        Device Identifier:        disk4s2
        File System Personality:  Unknown
        """
        let partitionUUIDOnly = """
        Device Identifier:        disk4s2
        Disk / Partition UUID:    partition-uuid
        File System Personality:  Unknown
        """
        let changedPartitionUUID = partitionUUIDOnly.replacingOccurrences(of: "partition-uuid", with: "different-partition-uuid")
        let mountedUUIDs = """
        Device Identifier:        disk4s2
        Volume UUID:              volume-uuid
        Disk / Partition UUID:    partition-uuid
        File System Personality:  Unknown
        """
        let knownFAT = """
        Device Identifier:        disk4s2
        Volume UUID:              volume-uuid
        File System Personality:  MS-DOS (FAT)
        """
        let changedFATVolume = knownFAT.replacingOccurrences(of: "volume-uuid", with: "different-uuid")

        XCTAssertTrue(DiskSafety.isSameKnownVolume(known, devicePath: "/dev/disk4s2", info: sameVolume))
        XCTAssertTrue(DiskSafety.isSameKnownVolume(known, devicePath: "/dev/disk4s2", info: partitionUUIDOnly))
        XCTAssertTrue(DiskSafety.isSameKnownVolume(known, devicePath: "/dev/disk4s2", info: mountedUUIDs))
        XCTAssertTrue(DiskSafety.isSameKnownVolume(known, devicePath: "/dev/disk4s2", info: missingUUID))
        XCTAssertFalse(DiskSafety.isSameKnownVolume(known, devicePath: "/dev/disk4s2", info: knownFAT))
        XCTAssertTrue(DiskSafety.canRetainUnmountedNTFSCandidate(known, devicePath: "/dev/disk4s2", info: knownFAT))
        XCTAssertFalse(DiskSafety.canRetainUnmountedNTFSCandidate(known, devicePath: "/dev/disk4s2", info: changedFATVolume))
        var mountedKnown = known
        mountedKnown.isUnmounted = false
        XCTAssertFalse(DiskSafety.canRetainUnmountedNTFSCandidate(mountedKnown, devicePath: "/dev/disk4s2", info: knownFAT))
        var noUUIDKnown = known
        noUUIDKnown.volumeUuid = nil
        noUUIDKnown.partitionUuid = nil
        XCTAssertFalse(DiskSafety.canRetainUnmountedNTFSCandidate(noUUIDKnown, devicePath: "/dev/disk4s2", info: knownFAT))
        XCTAssertTrue(DiskSafety.requiresUnmountedNTFSProbe(known, devicePath: "/dev/disk4s2", info: knownFAT))
        XCTAssertFalse(DiskSafety.requiresUnmountedNTFSProbe(known, devicePath: "/dev/disk4s2", info: changedFATVolume))
        XCTAssertFalse(DiskSafety.requiresUnmountedNTFSProbe(mountedKnown, devicePath: "/dev/disk4s2", info: knownFAT))
        XCTAssertFalse(DiskSafety.requiresUnmountedNTFSProbe(known, devicePath: "/dev/disk4s2", info: sameVolume.replacingOccurrences(of: "Unknown", with: "NTFS")))
        XCTAssertFalse(DiskSafety.isSameKnownVolume(known, devicePath: "/dev/disk4s2", info: changedPartitionUUID))
        XCTAssertFalse(DiskSafety.isSameKnownVolume(known, devicePath: "/dev/disk4s2", info: changedFATVolume))
        XCTAssertFalse(DiskSafety.isSameKnownVolume(known, devicePath: "/dev/disk4s1", info: sameVolume))
        XCTAssertFalse(DiskSafety.isSameKnownVolume(known, devicePath: "/dev/disk4s2", info: changedVolume))

        var withoutVolumeUUID = known
        withoutVolumeUUID.volumeUuid = nil
        XCTAssertFalse(DiskSafety.isSameKnownVolume(withoutVolumeUUID, devicePath: "/dev/disk4s2", info: knownFAT))
    }

    func testResolvedVolumeUUIDRetainsKnownIdentityWhenScanTemporarilyOmitsIt() {
        XCTAssertEqual(DeviceScanner.resolvedVolumeUUID(scanned: nil, known: "volume-uuid"), "volume-uuid")
        XCTAssertEqual(DeviceScanner.resolvedVolumeUUID(scanned: "", known: "volume-uuid"), "volume-uuid")
        XCTAssertEqual(DeviceScanner.resolvedVolumeUUID(scanned: "new-volume-uuid", known: "volume-uuid"), "new-volume-uuid")
        XCTAssertNil(DeviceScanner.resolvedVolumeUUID(scanned: nil, known: nil))
    }

    func testConfirmedFuseMountAcceptsIdentityOrTrustedMarker() {
        let mountOutput = """
        /dev/disk40s1 on /Volumes/Samsung USB (macfuse, local, nodev, synchronous, noatime)
        /dev/disk41s2 on /Volumes/SanDisk 32G (macfuse, local, nodev, synchronous, noatime)
        /dev/disk42s1 on /Volumes/Other (macfuse, local)
        /dev/disk43s1 on /Volumes/Legacy (macfuse, local, allow_other)
        /dev/disk44s1 on /Volumes/PreviouslyMounted (macfuse, local, allow_other)
        /dev/disk45s1 on /Volumes/NTFS3G (macfuse, local, allow_other)
        """
        let ventoy = """
        Device Identifier:        disk40s1
        File System Personality:  ExFAT
        Type (Bundle):            exfat
        Partition Type:           Windows_NTFS
        """
        let basicData = """
        Device Identifier:        disk41s2
        File System Personality:  MS-DOS
        Type (Bundle):            msdos
        Partition Type:           Microsoft Basic Data
        """
        let nonNTFS = """
        Device Identifier:        disk42s1
        File System Personality:  APFS
        Partition Type:           Apple_APFS
        """
        let ntfs = """
        Device Identifier:        disk43s1
        File System Personality:  Unknown (xntfs)
        Partition Type:           Microsoft Basic Data
        """
        let previouslyMounted = """
        Device Identifier:        disk44s1
        File System Personality:  ExFAT
        Type (Bundle):            exfat
        Partition Type:           Windows_NTFS
        """
        let ntfs3g = """
        Device Identifier:        disk45s1
        Format:                   NTFS-3g (macFUSE)
        Partition Type:           Microsoft Basic Data
        """

        XCTAssertTrue(DiskSafety.isKnownNonNTFSVolumeInfo(ventoy))
        XCTAssertTrue(DiskSafety.isKnownNonNTFSVolumeInfo(basicData))
        XCTAssertTrue(DiskSafety.isKnownNonNTFSVolumeInfo(nonNTFS))

        XCTAssertFalse(DiskSafety.isConfirmedNTFSFuseMount(
            mountOutput,
            deviceInfo: ventoy,
            devicePath: "/dev/disk40s1",
            mountPoint: "/Volumes/Samsung USB"
        ))
        XCTAssertFalse(DiskSafety.isConfirmedNTFSFuseMount(
            mountOutput,
            deviceInfo: basicData,
            devicePath: "/dev/disk41s2",
            mountPoint: "/Volumes/SanDisk 32G"
        ))
        XCTAssertFalse(DiskSafety.isConfirmedNTFSFuseMount(
            mountOutput,
            deviceInfo: nonNTFS,
            devicePath: "/dev/disk42s1",
            mountPoint: "/Volumes/Other"
        ))
        XCTAssertTrue(DiskSafety.isConfirmedNTFSFuseMount(
            mountOutput,
            deviceInfo: ntfs,
            devicePath: "/dev/disk43s1",
            mountPoint: "/Volumes/Legacy"
        ))
        XCTAssertTrue(DiskSafety.isConfirmedNTFSFuseMount(
            mountOutput,
            deviceInfo: ntfs3g,
            devicePath: "/dev/disk45s1",
            mountPoint: "/Volumes/NTFS3G"
        ))

        let markerPath = "/tmp/ntfs_mounted_disk44s1"
        try? FileManager.default.removeItem(atPath: markerPath)
        _ = FileManager.default.createFile(atPath: markerPath, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: markerPath) }
        XCTAssertTrue(DiskSafety.isConfirmedNTFSFuseMount(
            mountOutput,
            deviceInfo: previouslyMounted,
            devicePath: "/dev/disk44s1",
            mountPoint: "/Volumes/PreviouslyMounted"
        ))

        XCTAssertFalse(DiskSafety.isConfirmedNTFSFuseMount(
            mountOutput,
            deviceInfo: ntfs,
            devicePath: "/dev/disk43s1",
            mountPoint: "/Volumes/Wrong"
        ))
    }

    func testMountTableParsesReadOnlyFromKernelOptionsOnly() {
        let rw = MountTable.parseLine(
            "/dev/disk4s1 on /Volumes/Samsung USB (macfuse, local, nodev, synchronous, noatime, allow_other)"
        )
        let ro = MountTable.parseLine(
            "/dev/disk5s2 on /Volumes/Backup (xntfs, local, nodev, nosuid, read-only, noowners)"
        )
        let spaced = MountTable.parseLine(
            "/dev/disk7s1 on /Volumes/My Volume (Name) (macfuse, local, allow_other)"
        )

        XCTAssertEqual(rw?.devicePath, "/dev/disk4s1")
        XCTAssertEqual(rw?.mountPoint, "/Volumes/Samsung USB")
        XCTAssertEqual(rw?.driver, "macfuse")
        XCTAssertFalse(rw?.isReadOnly ?? true)
        XCTAssertTrue(rw?.isFUSE ?? false)

        XCTAssertEqual(ro?.driver, "xntfs")
        XCTAssertTrue(ro?.isReadOnly ?? false)
        XCTAssertFalse(ro?.isFUSE ?? true)

        // 卷名含括号时，选项组仍取行尾
        XCTAssertEqual(spaced?.mountPoint, "/Volumes/My Volume (Name)")
        XCTAssertEqual(spaced?.driver, "macfuse")
        XCTAssertFalse(spaced?.isReadOnly ?? true)
    }

    func testMountTableReadOnlyOnlyRejectsSiblingReadWriteRow() {
        let mounts = MountTable.parse("""
        /dev/disk5s2 on /Volumes/新加卷 1 (xntfs, local, nodev, nosuid, read-only, noowners)
        /dev/disk5s2 on /Volumes/新加卷 1 (macfuse, local, nodev, synchronous, noatime, allow_other)
        /dev/disk5s1 on /Volumes/新加卷 (xntfs, local, nodev, nosuid, read-only, noowners)
        """)
        XCTAssertEqual(MountTable.rows(for: "/dev/disk5s2", in: mounts).count, 2)
        XCTAssertFalse(MountTable.isReadOnlyOnly(devicePath: "/dev/disk5s2", mounts: mounts))
        XCTAssertTrue(MountTable.hasReadWrite(devicePath: "/dev/disk5s2", mounts: mounts))
        XCTAssertTrue(MountTable.isReadOnlyOnly(devicePath: "/dev/disk5s1", mounts: mounts))
        XCTAssertFalse(MountTable.hasReadWrite(devicePath: "/dev/disk5s1", mounts: mounts))
        XCTAssertFalse(MountTable.isReadOnlyOnly(devicePath: "/dev/disk9s1", mounts: mounts))
    }

    func testMountedXNTFSRequiresExactDeviceAndMountPoint() {
        let mountOutput = "/dev/disk5s2 on /Volumes/Backup (xntfs, local, nodev, nosuid, read-only, noowners)"

        XCTAssertTrue(DiskSafety.isMountedXNTFSFilesystem(
            mountOutput,
            devicePath: "/dev/disk5s2",
            mountPoint: "/Volumes/Backup"
        ))
        XCTAssertFalse(DiskSafety.isMountedXNTFSFilesystem(
            mountOutput,
            devicePath: "/dev/disk5s1",
            mountPoint: "/Volumes/Backup"
        ))
        XCTAssertFalse(DiskSafety.isMountedXNTFSFilesystem(
            mountOutput,
            devicePath: "/dev/disk5s2",
            mountPoint: "/Volumes/Other"
        ))
        XCTAssertFalse(DiskSafety.isMountedXNTFSFilesystem(
            "/dev/disk5s2 on /Volumes/Backup (msdos, local)",
            devicePath: "/dev/disk5s2",
            mountPoint: "/Volumes/Backup"
        ))
        XCTAssertFalse(DiskSafety.isMountedXNTFSFilesystem(
            "/dev/disk5s2 on /Volumes/Backup (ntfs, local)",
            devicePath: "/dev/disk5s2",
            mountPoint: "/Volumes/Backup"
        ))
        XCTAssertFalse(DiskSafety.isMountedXNTFSFilesystem(
            mountOutput,
            devicePath: "/dev/disk5",
            mountPoint: "/Volumes/Backup"
        ))
        XCTAssertTrue(DiskSafety.isMountedXNTFSFilesystem(
            "/dev/disk8 on /Volumes/移动临时存储 (xntfs, local, nodev, nosuid, read-only, noowners)",
            devicePath: "/dev/disk8",
            mountPoint: "/Volumes/移动临时存储"
        ))
        XCTAssertTrue(DiskSafety.isConfirmedNTFSFuseMount(
            "/dev/disk8 on /Volumes/移动临时存储 (ntfs-3g, local, allow_other)",
            deviceInfo: """
            Device Identifier:        disk8
            File System Personality:  NTFS
            Whole:                    Yes
            """,
            devicePath: "/dev/disk8",
            mountPoint: "/Volumes/移动临时存储"
        ))
    }

    func testFormattingRequiresExternalWholeDisk() {
        // 旧式：带 Internal=No
        let legacy = """
        Device Identifier:        disk4
        Device Location:         External
        Whole:                    Yes
        Internal:                 No
        Virtual:                  No
        Protocol:                 USB
        """

        // 新版 macOS 外接 USB 常见：无 Internal 字段，有 Removable Media
        let modernUSB = """
        Device Identifier:         disk4
        Device Node:               /dev/disk4
        Whole:                     Yes
        Part of Whole:             disk4
        Protocol:                  USB
        Device Location:           External
        Removable Media:           Removable
        Virtual:                   No
        """

        XCTAssertTrue(DiskSafety.isExternalFormattable(
            parentInfo: legacy,
            bootWholeDiskId: "disk1",
            parentDiskId: "disk4"
        ))
        XCTAssertTrue(DiskSafety.isExternalFormattable(
            parentInfo: modernUSB,
            bootWholeDiskId: "disk0",
            parentDiskId: "disk4"
        ))
        XCTAssertFalse(DiskSafety.isExternalFormattable(
            parentInfo: legacy,
            bootWholeDiskId: "disk4",
            parentDiskId: "disk4"
        ))
        XCTAssertFalse(DiskSafety.isExternalFormattable(
            parentInfo: legacy.replacingOccurrences(of: "Device Identifier:        disk4", with: "Device Identifier:        disk5"),
            bootWholeDiskId: "disk1",
            parentDiskId: "disk4"
        ))
    }

    func testFormattingRejectsInternalVirtualAndNonWholeDisk() {
        let internalDisk = """
        Device Identifier:        disk0
        Whole:                    Yes
        Internal:                 Yes
        Device Location:         Internal
        Virtual:                  No
        Protocol:                 SATA
        """
        let virtualDisk = """
        Device Identifier:        disk4
        Whole:                    Yes
        Internal:                 No
        Virtual:                  Yes
        Device Location:         External
        Protocol:                 Disk Image
        """
        let partition = """
        Device Identifier:        disk4s1
        Whole:                    No
        Internal:                 No
        Device Location:         External
        Virtual:                  No
        Protocol:                 USB
        """
        let incompleteInfo = """
        Device Identifier:        disk4
        Whole:                    Yes
        Protocol:                 USB
        """

        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: internalDisk, bootWholeDiskId: "disk1", parentDiskId: "disk0"))
        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: virtualDisk, bootWholeDiskId: "disk1", parentDiskId: "disk4"))
        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: partition, bootWholeDiskId: "disk1", parentDiskId: "disk4"))
        // 无 External / Removable 时不可格式化
        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: incompleteInfo, bootWholeDiskId: "disk1", parentDiskId: "disk4"))
        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: "", bootWholeDiskId: "disk1", parentDiskId: "disk4"))
        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: incompleteInfo, bootWholeDiskId: "", parentDiskId: "disk4"))
        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: incompleteInfo, bootWholeDiskId: "disk1", parentDiskId: "not-a-disk"))
    }

    func testParentDiskIdStripsNestedAPFSSuffixes() {
        XCTAssertEqual(DiskSafety.parentDiskId("disk4s1"), "disk4")
        XCTAssertEqual(DiskSafety.parentDiskId("/dev/disk5s2"), "disk5")
        XCTAssertEqual(DiskSafety.parentDiskId("disk3s3s1"), "disk3")
        XCTAssertEqual(DiskSafety.parentDiskId("disk0"), "disk0")
    }

    func testBootWholeDiskIdPrefersPhysicalStore() {
        let bootSnapshot = """
        Device Identifier:         disk3s3s1
        Whole:                     No
        Part of Whole:             disk3
        APFS Physical Store:       disk0s2
        Device Location:           Internal
        """
        XCTAssertEqual(DiskSafety.bootWholeDiskId(fromBootInfo: bootSnapshot), "disk0")

        let plain = """
        Device Identifier:         disk2s1
        Part of Whole:             disk2
        """
        XCTAssertEqual(DiskSafety.bootWholeDiskId(fromBootInfo: plain), "disk2")
    }

    func testMissingOrNonExternalDeviceTagsCannotBeFormatted() {
        XCTAssertFalse(DiskSafety.canFormat(fromListTags: nil))
        XCTAssertFalse(DiskSafety.canFormat(fromListTags: "USB"))
        XCTAssertFalse(DiskSafety.canFormat(fromListTags: "external, virtual"))
        XCTAssertFalse(DiskSafety.canFormat(fromListTags: "external"))
        XCTAssertFalse(DiskSafety.canFormat(fromListTags: "not external, physical"))
        XCTAssertFalse(DiskSafety.canFormat(fromListTags: "external, physical, synthesized"))
        XCTAssertTrue(DiskSafety.canFormat(fromListTags: "external, physical"))
    }

    func testDataPartitionMustBelongToConfirmedWholeDisk() {
        let listing = """
        /dev/disk4 (external, physical):
           1: EFI EFI                     disk4s1
           2: Microsoft Basic Data Backup disk4s2
        /dev/disk5 (disk image):
           1: Microsoft Basic Data Other  disk5s1
        """
        let xntfsListing = """
        /dev/disk6 (external, physical):
           1: EFI EFI                     disk6s1
           2: xNTFS Backup                 disk6s2
        """

        XCTAssertEqual(DiskSafety.dataPartition(fromListOutput: listing, parent: "/dev/disk4"), "/dev/disk4s2")
        XCTAssertEqual(DiskSafety.dataPartition(fromListOutput: xntfsListing, parent: "/dev/disk6"), "/dev/disk6s2")
        XCTAssertNil(DiskSafety.dataPartition(fromListOutput: listing, parent: "/dev/disk5"))
        XCTAssertNil(DiskSafety.dataPartition(fromListOutput: listing, parent: "/dev/disk6"))
        XCTAssertNil(DiskSafety.dataPartition(fromListOutput: listing, parent: "/dev/disk4s2"))
    }

    func testVolumeNameSanitizationIsBounded() {
        let name = DiskSafety.sanitizeVolumeName("  backup:/*?  ")
        XCTAssertEqual(name, "backup")
        XCTAssertLessThanOrEqual(name.count, 32)
    }
}

final class TrayDeviceStatusTests: XCTestCase {
    func testReadyStatusIgnoresUnmountedDevices() {
        XCTAssertEqual(TrayDeviceStatus(devices: []), .ready)
        XCTAssertEqual(TrayDeviceStatus(devices: [trayDevice(mounted: false, readOnly: true)]), .ready)
    }

    func testAllReadWriteStatus() {
        XCTAssertEqual(
            TrayDeviceStatus(devices: [trayDevice(mounted: true, readOnly: false)]),
            .allReadWrite
        )
    }

    func testAllReadOnlyStatus() {
        XCTAssertEqual(
            TrayDeviceStatus(devices: [trayDevice(mounted: true, readOnly: true)]),
            .allReadOnly
        )
    }

    func testMixedStatus() {
        XCTAssertEqual(
            TrayDeviceStatus(devices: [
                trayDevice(disk: "disk1s1", mounted: true, readOnly: false),
                trayDevice(disk: "disk2s1", mounted: true, readOnly: true)
            ]),
            .mixed
        )
    }

    private func trayDevice(
        disk: String = "disk1s1",
        mounted: Bool,
        readOnly: Bool
    ) -> NTFSDevice {
        NTFSDevice(
            disk: disk,
            devicePath: "/dev/\(disk)",
            volume: mounted ? "/Volumes/Test" : "",
            volumeName: "Test",
            volumeUuid: nil,
            isReadOnly: readOnly,
            options: "",
            isMounted: mounted,
            isUnmounted: !mounted,
            canFormat: false,
            capacity: nil
        )
    }
}

final class AutoMountTests: XCTestCase {
    func testMountedReadOnlyVolumeIsAlwaysACandidate() {
        let device = NTFSDevice(
            disk: "disk4s2",
            devicePath: "/dev/disk4s2",
            volume: "/Volumes/Backup",
            volumeName: "Backup",
            volumeUuid: "uuid-4",
            isReadOnly: true,
            options: "read-only",
            isMounted: true,
            isUnmounted: false,
            canFormat: true,
            capacity: nil
        )

        XCTAssertEqual(AutoMount.candidates(
            devices: [device],
            settings: AppSettings(),
            attempted: [],
            cooldown: [:],
            inProgress: [],
            explicit: false
        ).map(\.identity), [device.identity])
    }

    func testManualReadOnlyPreferenceBlocksAutoMount() {
        let device = NTFSDevice(
            disk: "disk4s2",
            devicePath: "/dev/disk4s2",
            volume: "/Volumes/Backup",
            volumeName: "Backup",
            volumeUuid: "uuid-4",
            isReadOnly: true,
            options: "read-only",
            isMounted: true,
            isUnmounted: false,
            canFormat: true,
            capacity: nil
        )
        var settings = AppSettings()
        settings.manuallyReadOnlyDevices = [device.identity]

        XCTAssertTrue(AutoMount.candidates(
            devices: [device],
            settings: settings,
            attempted: [],
            cooldown: [:],
            inProgress: [],
            explicit: true
        ).isEmpty)
    }

    func testMarkManualReadOnlyTracksDiskAndUUID() {
        let device = NTFSDevice(
            disk: "disk4s1",
            devicePath: "/dev/disk4s1",
            volume: "/Volumes/Samsung USB",
            volumeName: "Samsung USB",
            volumeUuid: "B280EF1C-95EF-4CC4-BCCE-A152DBA1528A",
            isReadOnly: true,
            options: "read-only",
            isMounted: true,
            isUnmounted: false,
            canFormat: true,
            capacity: nil
        )
        var settings = AppSettings()
        AutoMount.markManualReadOnly(device, settings: &settings)

        // uuid 缺失时仍能靠 disk 挡住
        let withoutUUID = NTFSDevice(
            disk: device.disk,
            devicePath: device.devicePath,
            volume: device.volume,
            volumeName: device.volumeName,
            volumeUuid: nil,
            isReadOnly: true,
            options: "read-only",
            isMounted: true,
            isUnmounted: false,
            canFormat: true,
            capacity: nil
        )
        XCTAssertTrue(AutoMount.isManuallyReadOnly(withoutUUID, settings: settings))
        XCTAssertTrue(AutoMount.candidates(
            devices: [withoutUUID],
            settings: settings,
            attempted: [],
            cooldown: [:],
            inProgress: [],
            explicit: true
        ).isEmpty)

        AutoMount.clearManualReadOnly(device, settings: &settings)
        XCTAssertFalse(AutoMount.isManuallyReadOnly(device, settings: settings))
    }

    func testDuplicateMountRowsCollapseToOneTarget() {
        let first = readOnlyDevice(disk: "disk5s1", name: "Samsung USB", uuid: nil)
        var second = readOnlyDevice(disk: "disk5s1", name: "Samsung USB", uuid: "vol-samsung")
        second.volumeUuid = "vol-samsung"
        let sandisk = readOnlyDevice(disk: "disk4s2", name: "SanDisk 32G", uuid: "vol-sandisk")
        var sandiskRW = sandisk
        sandiskRW.isReadOnly = false

        let targets = AutoMount.targets(
            devices: [sandiskRW, first, second],
            settings: AppSettings(),
            attempted: [],
            cooldown: [:],
            inProgress: [],
            explicit: false
        )
        XCTAssertEqual(targets.map(\.disk), ["disk5s1"])
    }

    func testSiblingDiskIdStaysBlockedAfterTheVolumeIsClaimed() {
        let mounted = readOnlyDevice(disk: "disk5s1", name: "Samsung USB", uuid: "vol-samsung")
        var alias = readOnlyDevice(disk: "disk6s1", name: "Samsung USB", uuid: "vol-samsung")
        alias.volume = "/Volumes/Samsung USB 1"
        alias.volumeUuid = "vol-samsung"
        let attempted = Set(AutoMount.recordKeys(mounted))

        XCTAssertTrue(alias.sameMount(as: mounted))
        XCTAssertTrue(AutoMount.candidates(
            devices: [alias],
            settings: AppSettings(),
            attempted: attempted,
            cooldown: [:],
            inProgress: [],
            explicit: false
        ).isEmpty)
    }

    func testDistinctVolumesBothStayCandidates() {
        let samsung = readOnlyDevice(disk: "disk5s1", name: "Samsung USB", uuid: "vol-samsung")
        let sandisk = readOnlyDevice(disk: "disk4s2", name: "SanDisk 32G", uuid: "vol-sandisk")
        let targets = AutoMount.targets(
            devices: [sandisk, samsung],
            settings: AppSettings(),
            attempted: [],
            cooldown: [:],
            inProgress: [],
            explicit: false
        )
        XCTAssertEqual(Set(targets.map(\.volumeName)), ["Samsung USB", "SanDisk 32G"])
    }

    func testSameLabelDifferentPartitionsBothStayCandidates() {
        let first = readOnlyDevice(disk: "disk8s1", name: "新加卷", uuid: "vol-a")
        let second = readOnlyDevice(disk: "disk8s2", name: "新加卷", uuid: "vol-b")
        let attempted = Set(AutoMount.recordKeys(first))
        XCTAssertFalse(AutoMount.isRecorded(second, in: attempted))
        let targets = AutoMount.targets(
            devices: [first, second],
            settings: AppSettings(),
            attempted: attempted,
            cooldown: [:],
            inProgress: [],
            explicit: false
        )
        XCTAssertEqual(Set(targets.map(\.disk)), ["disk8s2"])
        XCTAssertEqual(
            Set(AutoMount.targets(
                devices: [first, second],
                settings: AppSettings(),
                attempted: [],
                cooldown: [:],
                inProgress: [],
                explicit: false
            ).map(\.disk)),
            ["disk8s1", "disk8s2"]
        )
    }

    func testEmptyVolumeUUIDDoesNotAliasDistinctPartitions() {
        let first = readOnlyDevice(disk: "disk8s1", name: "新加卷", uuid: "")
        let second = readOnlyDevice(disk: "disk8s2", name: "新加卷", uuid: "")
        XCTAssertEqual(first.identity, "disk8s1")
        XCTAssertEqual(second.identity, "disk8s2")
        XCTAssertFalse(first.sameMount(as: second))
        XCTAssertFalse(AutoMount.isRecorded(second, in: Set(AutoMount.recordKeys(first))))
        XCTAssertEqual(
            Set(AutoMount.targets(
                devices: [first, second],
                settings: AppSettings(),
                attempted: [],
                cooldown: [:],
                inProgress: [],
                explicit: false
            ).map(\.disk)),
            ["disk8s1", "disk8s2"]
        )
    }

    func testMBRSameLabelPartitionsBothStayCandidates() {
        let first = readOnlyDevice(disk: "disk8s1", name: "新加卷", uuid: nil)
        var second = readOnlyDevice(disk: "disk8s2", name: "新加卷", uuid: nil)
        second.volume = "/Volumes/新加卷 1"
        XCTAssertEqual(first.identity, "disk8s1")
        XCTAssertFalse(AutoMount.isRecorded(second, in: Set(AutoMount.recordKeys(first))))
        XCTAssertEqual(
            Set(AutoMount.targets(
                devices: [first, second],
                settings: AppSettings(),
                attempted: [],
                cooldown: [:],
                inProgress: [],
                explicit: false
            ).map(\.disk)),
            ["disk8s1", "disk8s2"]
        )
    }

    func testPruningStaleDropsUnpluggedVolumeButKeepsLiveFailure() {
        let first = readOnlyDevice(disk: "disk8s1", name: "新加卷", uuid: nil)
        let second = readOnlyDevice(disk: "disk8s2", name: "新加卷", uuid: nil)
        var attempted = Set(AutoMount.recordKeys(first) + AutoMount.recordKeys(second))
        attempted = AutoMount.pruningStale(attempted, devices: [second])
        XCTAssertFalse(AutoMount.isRecorded(first, in: attempted))
        XCTAssertTrue(AutoMount.isRecorded(second, in: attempted))
        XCTAssertEqual(
            AutoMount.candidates(
                devices: [first, second],
                settings: AppSettings(),
                attempted: attempted,
                cooldown: [:],
                inProgress: [],
                explicit: false
            ).map(\.disk),
            ["disk8s1"]
        )
    }

    func testReinsertAfterUnplugIsACandidateAgain() {
        let first = readOnlyDevice(disk: "disk8s1", name: "新加卷", uuid: nil)
        var attempted = Set(AutoMount.recordKeys(first))
        attempted = AutoMount.pruningStale(attempted, devices: [])
        XCTAssertTrue(attempted.isEmpty)
        XCTAssertEqual(
            AutoMount.candidates(
                devices: [first],
                settings: AppSettings(),
                attempted: attempted,
                cooldown: [:],
                inProgress: [],
                explicit: false
            ).map(\.disk),
            ["disk8s1"]
        )
    }

    func testCoalescedScanStillAppliesAutoMount() {
        XCTAssertTrue(AutoMount.shouldApply(scanRequestedAuto: false, coalescedAuto: true))
        XCTAssertTrue(AutoMount.shouldApply(scanRequestedAuto: true, coalescedAuto: false))
        XCTAssertFalse(AutoMount.shouldApply(scanRequestedAuto: false, coalescedAuto: false))
    }

    private func readOnlyDevice(disk: String, name: String, uuid: String?) -> NTFSDevice {
        NTFSDevice(
            disk: disk,
            devicePath: "/dev/\(disk)",
            volume: "/Volumes/\(name)",
            volumeName: name,
            volumeUuid: uuid,
            isReadOnly: true,
            options: "read-only",
            isMounted: true,
            isUnmounted: false,
            canFormat: true,
            capacity: nil
        )
    }
}

final class MountIdentityTests: XCTestCase {
    func testDuplicateMountLinesCollapseAndKeepReadWrite() {
        let readOnly = sample(disk: "disk5s1", name: "Samsung USB", readOnly: true, uuid: nil)
        var readWrite = sample(disk: "disk5s1", name: "Samsung USB", readOnly: false, uuid: "vol-samsung")
        readWrite.volumeUuid = "vol-samsung"
        let sandisk = sample(disk: "disk4s2", name: "SanDisk 32G", readOnly: false, uuid: "vol-sandisk")

        let collapsed = DeviceScanner.collapsingDuplicates([sandisk, readOnly, readWrite])
        XCTAssertEqual(collapsed.map(\.disk).sorted(), ["disk4s2", "disk5s1"])
        let samsung = collapsed.first { $0.disk == "disk5s1" }
        XCTAssertEqual(samsung?.isReadWrite, true)
        XCTAssertEqual(samsung?.volumeUuid, "vol-samsung")
    }

    func testSameLabelDifferentPartitionsDoNotCollapse() {
        let first = sample(disk: "disk8s1", name: "新加卷", readOnly: true, uuid: "vol-a")
        let second = sample(disk: "disk8s2", name: "新加卷", readOnly: true, uuid: "vol-b")
        XCTAssertFalse(first.sameMount(as: second))
        XCTAssertTrue(first.isDistinctPartition(from: second))
        let collapsed = DeviceScanner.collapsingDuplicates([first, second])
        XCTAssertEqual(collapsed.map(\.disk).sorted(), ["disk8s1", "disk8s2"])
    }

    func testWholeDiskSuperfloppyDoesNotCollapseWithPartition() {
        let whole = sample(disk: "disk8", name: "移动临时存储", readOnly: true, uuid: nil)
        let part = sample(disk: "disk5s1", name: "移动临时存储", readOnly: true, uuid: nil)
        XCTAssertTrue(whole.isDistinctPartition(from: part))
        XCTAssertFalse(whole.sameMount(as: part))
        let collapsed = DeviceScanner.collapsingDuplicates([whole, part])
        XCTAssertEqual(Set(collapsed.map(\.disk)), ["disk5s1", "disk8"])
    }

    func testRepeatedSuccessToastIsSuppressed() {
        let now = Date()
        var recent: [String: Date] = [:]
        let message = "设备 Samsung USB 已成功挂载为读写模式"
        XCTAssertTrue(ToastDedup.shouldPresent(message, recent: recent, now: now))
        recent[message] = now
        XCTAssertFalse(ToastDedup.shouldPresent(message, recent: recent, now: now.addingTimeInterval(3)))
        XCTAssertTrue(ToastDedup.shouldPresent(
            "设备 SanDisk 32G 已成功挂载为读写模式",
            recent: recent,
            now: now.addingTimeInterval(3)
        ))
        XCTAssertTrue(ToastDedup.shouldPresent(message, recent: recent, now: now.addingTimeInterval(ToastDedup.window)))
    }

    private func sample(disk: String, name: String, readOnly: Bool, uuid: String?) -> NTFSDevice {
        NTFSDevice(
            disk: disk,
            devicePath: "/dev/\(disk)",
            volume: "/Volumes/\(name)",
            volumeName: name,
            volumeUuid: uuid,
            isReadOnly: readOnly,
            options: readOnly ? "read-only" : "local",
            isMounted: true,
            isUnmounted: false,
            canFormat: true,
            capacity: nil
        )
    }
}

final class MountBackendPolicyTests: XCTestCase {
    func testFSKitFailsClosedBelowSupportedSystemVersion() {
        XCTAssertThrowsError(try MountBackendPolicy.validate(
            .fsKit,
            systemVersion: NigateSystemVersion(major: 15, minor: 3, patch: 0),
            isFSKitControlPlaneAvailable: true
        )) { error in
            XCTAssertEqual(error as? MountBackendPolicyError, .fsKitRequiresMacOS15_4)
        }
    }

    func testFSKitDoesNotFallbackWhenControlPlaneIsUnavailable() {
        XCTAssertThrowsError(try MountBackendPolicy.validate(
            .fsKit,
            systemVersion: NigateSystemVersion(major: 15, minor: 4, patch: 0),
            isFSKitControlPlaneAvailable: false
        )) { error in
            XCTAssertEqual(error as? MountBackendPolicyError, .fsKitControlPlaneUnavailable)
        }
    }

    func testCompatibilityBackendIsExplicitlyAllowed() throws {
        XCTAssertNoThrow(try MountBackendPolicy.validate(
            .ntfs3gCompatibility,
            systemVersion: NigateSystemVersion(major: 14, minor: 0, patch: 0),
            isFSKitControlPlaneAvailable: false
        ))
    }

    func testSanitizeRepairsFSKitWhenControlPlaneUnavailable() {
        XCTAssertEqual(
            MountBackendPolicy.sanitize(
                .fsKit,
                systemVersion: NigateSystemVersion(major: 15, minor: 4, patch: 0),
                isFSKitControlPlaneAvailable: false
            ),
            .ntfs3gCompatibility
        )
        XCTAssertEqual(
            MountBackendPolicy.sanitize(
                .fsKit,
                systemVersion: NigateSystemVersion(major: 15, minor: 4, patch: 0),
                isFSKitControlPlaneAvailable: true
            ),
            .fsKit
        )
        XCTAssertEqual(
            MountBackendPolicy.sanitize(
                .ntfs3gCompatibility,
                systemVersion: NigateSystemVersion(major: 15, minor: 4, patch: 0),
                isFSKitControlPlaneAvailable: false
            ),
            .ntfs3gCompatibility
        )
        XCTAssertFalse(MountBackendPolicy.canUseFSKit(
            systemVersion: NigateSystemVersion(major: 15, minor: 4, patch: 0),
            isFSKitControlPlaneAvailable: false
        ))
    }
}
