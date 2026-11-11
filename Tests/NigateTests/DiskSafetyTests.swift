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

    func testNTFSFilesystemRecognizesXNTFSWithoutSubstringFalsePositives() {
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("File System Personality: xntfs"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("File System Personality: Unknown (xntfs)"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("Format: Unknown (xntfs)"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("格式: 未知 (xntfs)"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("File System Personality: NTFS"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("File System Personality: Windows_NTFS"))
        XCTAssertTrue(DiskSafety.isNTFSFilesystem("/dev/disk4s2 on /Volumes/Backup (xntfs, local, read-only)"))
        XCTAssertFalse(DiskSafety.isNTFSFilesystem("Volume Name: Unknown (xntfs)"))
        XCTAssertFalse(DiskSafety.isNTFSFilesystem("卷名: 未知 (xntfs)"))
        XCTAssertFalse(DiskSafety.isNTFSFilesystem("File System Personality: Unknown (exFAT)"))
        XCTAssertFalse(DiskSafety.isNTFSFilesystem("Volume Name: My NTFS Backup"))
        XCTAssertFalse(DiskSafety.isNTFSFilesystem("File System Personality: exFAT"))
    }

    func testNTFSVolumeInfoAcceptsPartitionTypeWhenPersonalityMisreports() {
        let contradictory = """
        Device Identifier:        disk4s1
        Volume Name:              Samsung USB
        File System Personality:  ExFAT
        Type (Bundle):            msdos
        Partition Type:           Microsoft Basic Data
        """
        // personality 误报时，单靠 personality 不能定 NTFS
        XCTAssertFalse(DiskSafety.isNTFSVolumeInfo(contradictory))

        let partitionNTFS = """
        Device Identifier:        disk4s1
        Volume Name:              Samsung USB
        File System Personality:  ExFAT
        Type (Bundle):            msdos
        Partition Type:           Windows_NTFS
        """
        XCTAssertTrue(DiskSafety.isNTFSVolumeInfo(partitionNTFS))

        let plainNTFS = """
        File System Personality:  NTFS
        Partition Type:           Windows_NTFS
        """
        XCTAssertTrue(DiskSafety.isNTFSVolumeInfo(plainNTFS))
    }

    func testConfirmedFuseMountPrefersMountFactOverPersonality() {
        // 实机 mount 表通常不回显 allow_other
        let mountOutput = """
        /dev/disk4s1 on /Volumes/Samsung USB (macfuse, local, nodev, synchronous, noatime)
        /dev/disk5s2 on /Volumes/SanDisk 32G (macfuse, local, nodev, synchronous, noatime)
        /dev/disk6s1 on /Volumes/Other (macfuse, local)
        /dev/disk7s1 on /Volumes/Legacy (macfuse, local, allow_other)
        """
        let samsung = """
        Device Identifier:        disk4s1
        File System Personality:  ExFAT
        Type (Bundle):            exfat
        Partition Type:           Windows_NTFS
        """
        let sandisk = """
        Device Identifier:        disk5s2
        File System Personality:  MS-DOS
        Type (Bundle):            msdos
        Partition Type:           Microsoft Basic Data
        """
        let nonNTFS = """
        Device Identifier:        disk6s1
        File System Personality:  APFS
        Partition Type:           Apple_APFS
        """
        let legacyNoIdentity = """
        Device Identifier:        disk7s1
        File System Personality:  MS-DOS
        """

        XCTAssertTrue(DiskSafety.isConfirmedNTFSFuseMount(
            mountOutput,
            deviceInfo: samsung,
            devicePath: "/dev/disk4s1",
            mountPoint: "/Volumes/Samsung USB"
        ))
        XCTAssertTrue(DiskSafety.isConfirmedNTFSFuseMount(
            mountOutput,
            deviceInfo: sandisk,
            devicePath: "/dev/disk5s2",
            mountPoint: "/Volumes/SanDisk 32G"
        ))
        XCTAssertFalse(DiskSafety.isConfirmedNTFSFuseMount(
            mountOutput,
            deviceInfo: nonNTFS,
            devicePath: "/dev/disk6s1",
            mountPoint: "/Volumes/Other"
        ))
        // 无分区身份时，依赖 allow_other 特征选项
        XCTAssertTrue(DiskSafety.isConfirmedNTFSFuseMount(
            mountOutput,
            deviceInfo: legacyNoIdentity,
            devicePath: "/dev/disk7s1",
            mountPoint: "/Volumes/Legacy"
        ))
        XCTAssertFalse(DiskSafety.isConfirmedNTFSFuseMount(
            mountOutput,
            deviceInfo: samsung,
            devicePath: "/dev/disk4s1",
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
        let info = """
        Device Identifier:        disk4
        Device Location:         External
        Whole:                    Yes
        Internal:                 No
        Virtual:                  No
        Protocol:                 USB
        """

        XCTAssertTrue(DiskSafety.isExternalFormattable(
            parentInfo: info,
            bootWholeDiskId: "disk1",
            parentDiskId: "disk4"
        ))
        XCTAssertFalse(DiskSafety.isExternalFormattable(
            parentInfo: info,
            bootWholeDiskId: "disk4",
            parentDiskId: "disk4"
        ))
        XCTAssertFalse(DiskSafety.isExternalFormattable(
            parentInfo: info.replacingOccurrences(of: "Device Identifier:        disk4", with: "Device Identifier:        disk5"),
            bootWholeDiskId: "disk1",
            parentDiskId: "disk4"
        ))
    }

    func testFormattingRejectsInternalVirtualAndNonWholeDisk() {
        let internalDisk = """
        Whole:                    Yes
        Internal:                 Yes
        Device Location:         Internal
        Virtual:                  No
        Protocol:                 SATA
        """
        let virtualDisk = """
        Whole:                    Yes
        Internal:                 No
        Virtual:                  Yes
        Device Location:         External
        Protocol:                 Disk Image
        """
        let partition = """
        Whole:                    No
        Internal:                 No
        Device Location:         External
        Virtual:                  No
        Protocol:                 USB
        """
        let incompleteInfo = """
        Whole:                    Yes
        Protocol:                 USB
        """

        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: internalDisk, bootWholeDiskId: "disk1", parentDiskId: "disk4"))
        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: virtualDisk, bootWholeDiskId: "disk1", parentDiskId: "disk4"))
        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: partition, bootWholeDiskId: "disk1", parentDiskId: "disk4"))
        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: incompleteInfo, bootWholeDiskId: "disk1", parentDiskId: "disk4"))
        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: "", bootWholeDiskId: "disk1", parentDiskId: "disk4"))
        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: incompleteInfo, bootWholeDiskId: "", parentDiskId: "disk4"))
        XCTAssertFalse(DiskSafety.isExternalFormattable(parentInfo: incompleteInfo, bootWholeDiskId: "disk1", parentDiskId: "not-a-disk"))
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
