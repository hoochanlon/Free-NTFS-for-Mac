#ifndef NigateNTFSEngine_h
#define NigateNTFSEngine_h

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NigateBlockIO {
    void *ctx;
    int64_t (*pread)(void *ctx, void *buf, int64_t count, int64_t offset);
    int64_t (*pwrite)(void *ctx, const void *buf, int64_t count, int64_t offset);
    int (*sync)(void *ctx);
    int64_t (*size)(void *ctx);
} NigateBlockIO;

typedef struct NigateNTFSVolume NigateNTFSVolume;

typedef struct NigateNTFSItemInfo {
    uint64_t mft_no;
    uint32_t mode;
    uint32_t nlink;
    uint64_t size;
    uint64_t alloc_size;
    int64_t atime_sec;
    int64_t mtime_sec;
    int64_t ctime_sec;
    int64_t birth_sec;
    bool is_dir;
    bool is_symlink;
    bool is_file;
} NigateNTFSItemInfo;

typedef struct NigateNTFSDirEntry {
    uint64_t mft_no;
    uint64_t next_pos;
    uint8_t type; /* NTFS_DT_* */
    char name[1024];
} NigateNTFSDirEntry;

/// 只读探测 boot sector：返回 1=NTFS，0=非 NTFS，-1=IO 错误。
int nigate_ntfs_probe_boot(const NigateBlockIO *io, char *name_out, size_t name_cap);

NigateNTFSVolume *nigate_ntfs_mount(const NigateBlockIO *io, bool read_only, char *err, size_t err_cap);
void nigate_ntfs_umount(NigateNTFSVolume *vol, bool force);

bool nigate_ntfs_is_read_only(const NigateNTFSVolume *vol);
const char *nigate_ntfs_volume_name(const NigateNTFSVolume *vol);
uint64_t nigate_ntfs_cluster_size(const NigateNTFSVolume *vol);
uint64_t nigate_ntfs_total_clusters(const NigateNTFSVolume *vol);
uint64_t nigate_ntfs_free_clusters(NigateNTFSVolume *vol);
uint64_t nigate_ntfs_root_mft(const NigateNTFSVolume *vol);

int nigate_ntfs_item_info(NigateNTFSVolume *vol, uint64_t mft_no, NigateNTFSItemInfo *out);
int nigate_ntfs_lookup(NigateNTFSVolume *vol, uint64_t dir_mft, const char *name, uint64_t *out_mft);
int nigate_ntfs_readdir(NigateNTFSVolume *vol, uint64_t dir_mft, int64_t *pos,
                        NigateNTFSDirEntry *out, int max_count, int *written);
int nigate_ntfs_read(NigateNTFSVolume *vol, uint64_t mft_no, int64_t offset,
                     void *buf, int64_t count, int64_t *got);
int nigate_ntfs_write(NigateNTFSVolume *vol, uint64_t mft_no, int64_t offset,
                      const void *buf, int64_t count, int64_t *wrote);
int nigate_ntfs_truncate(NigateNTFSVolume *vol, uint64_t mft_no, int64_t new_size);
int nigate_ntfs_create(NigateNTFSVolume *vol, uint64_t dir_mft, const char *name,
                       bool is_dir, uint64_t *out_mft);
int nigate_ntfs_unlink(NigateNTFSVolume *vol, uint64_t dir_mft, uint64_t item_mft, const char *name);
int nigate_ntfs_rename(NigateNTFSVolume *vol,
                       uint64_t src_dir, uint64_t item_mft, const char *src_name,
                       uint64_t dst_dir, const char *dst_name,
                       uint64_t over_mft /* 0 if none */);
int nigate_ntfs_readlink(NigateNTFSVolume *vol, uint64_t mft_no, char *out, size_t out_cap);
int nigate_ntfs_symlink(NigateNTFSVolume *vol, uint64_t dir_mft, const char *name,
                        const char *target, uint64_t *out_mft);
int nigate_ntfs_link(NigateNTFSVolume *vol, uint64_t item_mft, uint64_t dir_mft, const char *name);
int nigate_ntfs_sync(NigateNTFSVolume *vol);

#ifdef __cplusplus
}
#endif

#endif /* NigateNTFSEngine_h */
