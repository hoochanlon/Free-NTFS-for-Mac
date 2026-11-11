import XCTest
@testable import Nigate

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
}
