import XCTest
@testable import Nigate
import NigateFSKitCore

final class DiskSafetyTests: XCTestCase {
    func testPartitionAndWholeDiskBoundaries() {
        XCTAssertTrue(DiskSafety.isPartition("/dev/disk4s2"))
        XCTAssertFalse(DiskSafety.isPartition("/dev/disk4"))
        XCTAssertTrue(DiskSafety.isWholeDisk("/dev/disk4"))
        XCTAssertFalse(DiskSafety.isWholeDisk("/dev/disk4s2"))
        XCTAssertEqual(DiskSafety.parentDiskPath("/dev/disk4s2"), "/dev/disk4")
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

final class AutoMountTests: XCTestCase {
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
        var settings = AppSettings(autoMount: true)
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
        var settings = AppSettings(autoMount: true)
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
