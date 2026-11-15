import XCTest
@testable import Nigate

final class VolumeCapacityTests: XCTestCase {
    private let usb = "/dev/disk8s2"
    private let volume = "/Volumes/SanDisk 32G"
    private let usbTotal: Int64 = 32_011_000_000
    private let usbAvailable: Int64 = 23_430_000_000
    private let hostTotal: Int64 = 245_110_000_000
    private let hostAvailable: Int64 = 23_430_000_000

    func testParsePosixDfKeepsSpacedMountPoint() {
        let stdout = """
        Filesystem 1024-blocks Used Available Capacity Mounted on
        /dev/disk8s2 31260742 8388671 22872071 27% /Volumes/SanDisk 32G
        """
        let row = VolumeCapacity.parseDf(stdout)
        XCTAssertEqual(row?.filesystem, "/dev/disk8s2")
        XCTAssertEqual(row?.mountPoint, "/Volumes/SanDisk 32G")
        XCTAssertEqual(row?.total, 31_260_742 * 1024)
        XCTAssertEqual(row?.available, 22_872_071 * 1024)
    }

    func testParseDarwinDfWithInodeColumns() {
        let stdout = """
        Filesystem     1024-blocks      Used Available Capacity  iused      ifree %iused  Mounted on
        /dev/disk8s2        31260742  8388671  22872071    27%   12345   99999999    0%   /Volumes/SanDisk 32G
        """
        let row = VolumeCapacity.parseDf(stdout)
        XCTAssertEqual(row?.filesystem, "/dev/disk8s2")
        XCTAssertEqual(row?.mountPoint, "/Volumes/SanDisk 32G")
        XCTAssertEqual(row?.total, 31_260_742 * 1024)
    }

    func testParseWrappedDfLine() {
        let stdout = """
        Filesystem     1024-blocks      Used Available Capacity  iused      ifree %iused  Mounted on
        fuse-ntfs-3g@/dev/disk8s2
                               31260742  8388671  22872071    27%   1000  99999999    0%   /Volumes/SanDisk 32G
        """
        let row = VolumeCapacity.parseDf(stdout)
        XCTAssertEqual(row?.filesystem, "fuse-ntfs-3g@/dev/disk8s2")
        XCTAssertEqual(row?.mountPoint, "/Volumes/SanDisk 32G")
        XCTAssertEqual(row?.total, 31_260_742 * 1024)
    }

    func testHostDiskDfIsNotTrustedDuringRemountWindow() {
        let stdout = """
        Filesystem 1024-blocks Used Available Capacity Mounted on
        /dev/disk3s5 239365234 216445312 22919922 91% /System/Volumes/Data
        """
        let row = VolumeCapacity.parseDf(stdout)
        let trusted = VolumeCapacity.trustedDf(
            row,
            devicePath: usb,
            volume: volume,
            partitionTotal: usbTotal
        )
        XCTAssertNil(trusted)
    }

    func testDeviceMismatchIsRejectedEvenWhenMountPointMatches() {
        let row = VolumeCapacity.DfRow(
            filesystem: "/dev/disk3s5",
            total: usbTotal,
            used: usbTotal - usbAvailable,
            available: usbAvailable,
            mountPoint: volume
        )
        XCTAssertNil(
            VolumeCapacity.trustedDf(row, devicePath: usb, volume: volume, partitionTotal: usbTotal)
        )
    }

    func testSizeMismatchRejectsHostStatfsOnCorrectLookingMount() {
        let row = VolumeCapacity.DfRow(
            filesystem: usb,
            total: hostTotal,
            used: hostTotal - hostAvailable,
            available: hostAvailable,
            mountPoint: volume
        )
        XCTAssertNil(
            VolumeCapacity.trustedDf(row, devicePath: usb, volume: volume, partitionTotal: usbTotal)
        )
        XCTAssertFalse(VolumeCapacity.totalsAgree(hostTotal, usbTotal))
    }

    func testTrustedFuseDfMatchesPartition() {
        let row = VolumeCapacity.DfRow(
            filesystem: "fuse-ntfs-3g@/dev/disk8s2",
            total: 31_260_742 * 1024,
            used: 8_388_671 * 1024,
            available: 22_872_071 * 1024,
            mountPoint: volume
        )
        let trusted = VolumeCapacity.trustedDf(
            row,
            devicePath: usb,
            volume: volume,
            partitionTotal: usbTotal
        )
        XCTAssertEqual(trusted?.available, row.available)
        XCTAssertTrue(VolumeCapacity.totalsAgree(row.total, usbTotal))
    }

    func testResolveKeepsPreviousWhenDfHitsHostDisk() {
        let previous = Capacity(total: usbTotal, used: usbTotal - usbAvailable, available: usbAvailable)
        let partition = Capacity(total: usbTotal, used: 0, available: usbTotal)
        let resolved = VolumeCapacity.resolve(df: nil, partition: partition, previous: previous)
        XCTAssertEqual(resolved?.total, usbTotal)
        XCTAssertEqual(resolved?.available, usbAvailable)
        XCTAssertEqual(resolved?.used, usbTotal - usbAvailable)
    }

    func testResolvePrefersPartitionTotalAndTrustedDfAvailable() {
        let partition = Capacity(total: usbTotal, used: 0, available: usbTotal)
        let df = Capacity(total: 31_260_742 * 1024, used: 8_388_671 * 1024, available: 22_872_071 * 1024)
        let resolved = VolumeCapacity.resolve(df: df, partition: partition, previous: nil)
        XCTAssertEqual(resolved?.total, usbTotal)
        XCTAssertEqual(resolved?.available, df.available)
        XCTAssertEqual(resolved?.used, usbTotal - df.available)
    }

    func testParseDiskutilUsesPartitionBytes() {
        let info = """
        Device Identifier:        disk8s2
        Volume Name:              SanDisk 32G
        Total Size:               32.0 GB (32011000000 Bytes) (exactly 62521484 512-Byte Units)
        Volume Used Space:        8.6 GB (8581000000 Bytes)
        Volume Free Space:        23.4 GB (23430000000 Bytes)
        """
        let capacity = VolumeCapacity.parseDiskutil(info)
        XCTAssertEqual(capacity?.total, 32_011_000_000)
        XCTAssertEqual(capacity?.available, 23_430_000_000)
        XCTAssertEqual(capacity?.used, 8_581_000_000)
    }

    func testScreenshotRemountKeepsUsbCapacityInsteadOfHostDisk() {
        let hostDf = """
        Filesystem 1024-blocks Used Available Capacity Mounted on
        /dev/disk3s5 239365234 216445312 22919922 91% /System/Volumes/Data
        """
        let partition = Capacity(total: usbTotal, used: 0, available: usbTotal)
        let previous = Capacity(total: usbTotal, used: usbTotal - usbAvailable, available: usbAvailable)
        let df = VolumeCapacity.trustedDf(
            VolumeCapacity.parseDf(hostDf),
            devicePath: usb,
            volume: volume,
            partitionTotal: partition.total
        )
        let resolved = VolumeCapacity.resolve(df: df, partition: partition, previous: previous)
        XCTAssertNil(df)
        XCTAssertEqual(resolved?.total, usbTotal)
        XCTAssertEqual(resolved?.available, usbAvailable)
        XCTAssertNotEqual(resolved?.total, hostTotal)
    }
}
