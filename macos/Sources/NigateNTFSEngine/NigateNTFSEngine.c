#include "NigateNTFSEngine.h"

/* Homebrew ntfs-3g headers 依赖这些 feature macros，但不会自动提供 config.h。 */
#ifndef HAVE_TIME_H
#define HAVE_TIME_H 1
#endif
#ifndef HAVE_SYS_STAT_H
#define HAVE_SYS_STAT_H 1
#endif
#ifndef HAVE_STDARG_H
#define HAVE_STDARG_H 1
#endif
#ifndef HAVE_SYS_TYPES_H
#define HAVE_SYS_TYPES_H 1
#endif
#ifndef HAVE_GETTIMEOFDAY
#define HAVE_GETTIMEOFDAY 1
#endif

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

#include <ntfs-3g/device.h>
#include <ntfs-3g/dir.h>
#include <ntfs-3g/inode.h>
#include <ntfs-3g/attrib.h>
#include <ntfs-3g/layout.h>
#include <ntfs-3g/types.h>
#include <ntfs-3g/unistr.h>
#include <ntfs-3g/volume.h>
#include <ntfs-3g/security.h>

struct NigateNTFSVolume {
    NigateBlockIO io;
    struct ntfs_device *dev;
    ntfs_volume *vol;
    bool read_only;
    char name[256];
};

static int64_t io_pread(void *ctx, void *buf, int64_t count, int64_t offset) {
    NigateBlockIO *io = (NigateBlockIO *)ctx;
    if (!io || !io->pread) return -1;
    return io->pread(io->ctx, buf, count, offset);
}

static int64_t io_pwrite(void *ctx, const void *buf, int64_t count, int64_t offset) {
    NigateBlockIO *io = (NigateBlockIO *)ctx;
    if (!io || !io->pwrite) return -1;
    return io->pwrite(io->ctx, buf, count, offset);
}

static int io_sync(void *ctx) {
    NigateBlockIO *io = (NigateBlockIO *)ctx;
    if (!io || !io->sync) return 0;
    return io->sync(io->ctx);
}

static int64_t io_size(void *ctx) {
    NigateBlockIO *io = (NigateBlockIO *)ctx;
    if (!io || !io->size) return -1;
    return io->size(io->ctx);
}

/* ---- ntfs device ops over NigateBlockIO ---- */

typedef struct {
    NigateBlockIO io;
    int64_t pos;
    int64_t size;
    int open;
} NigateDevPriv;

static int nigate_dev_open(struct ntfs_device *dev, int flags) {
    NigateDevPriv *p = (NigateDevPriv *)dev->d_private;
    if (!p) return -1;
    if (p->open) {
        errno = EBUSY;
        return -1;
    }
    p->size = io_size(&p->io);
    if (p->size < 0) {
        errno = EIO;
        return -1;
    }
    p->pos = 0;
    p->open = 1;
    NDevSetOpen(dev);
    if ((flags & O_RDWR) == 0) {
        NDevSetReadOnly(dev);
    }
    NDevSetBlock(dev);
    return 0;
}

static int nigate_dev_close(struct ntfs_device *dev) {
    NigateDevPriv *p = (NigateDevPriv *)dev->d_private;
    if (!p || !p->open) {
        errno = EBADF;
        return -1;
    }
    (void)io_sync(&p->io);
    p->open = 0;
    NDevClearOpen(dev);
    return 0;
}

static s64 nigate_dev_seek(struct ntfs_device *dev, s64 offset, int whence) {
    NigateDevPriv *p = (NigateDevPriv *)dev->d_private;
    if (!p || !p->open) {
        errno = EBADF;
        return -1;
    }
    int64_t next = p->pos;
    switch (whence) {
        case SEEK_SET: next = offset; break;
        case SEEK_CUR: next = p->pos + offset; break;
        case SEEK_END: next = p->size + offset; break;
        default:
            errno = EINVAL;
            return -1;
    }
    if (next < 0) {
        errno = EINVAL;
        return -1;
    }
    p->pos = next;
    return next;
}

static s64 nigate_dev_read(struct ntfs_device *dev, void *buf, s64 count) {
    NigateDevPriv *p = (NigateDevPriv *)dev->d_private;
    if (!p || !p->open) {
        errno = EBADF;
        return -1;
    }
    int64_t n = io_pread(&p->io, buf, count, p->pos);
    if (n < 0) {
        errno = EIO;
        return -1;
    }
    p->pos += n;
    return n;
}

static s64 nigate_dev_write(struct ntfs_device *dev, const void *buf, s64 count) {
    NigateDevPriv *p = (NigateDevPriv *)dev->d_private;
    if (!p || !p->open) {
        errno = EBADF;
        return -1;
    }
    if (NDevReadOnly(dev)) {
        errno = EROFS;
        return -1;
    }
    int64_t n = io_pwrite(&p->io, buf, count, p->pos);
    if (n < 0) {
        errno = EIO;
        return -1;
    }
    p->pos += n;
    if (p->pos > p->size) p->size = p->pos;
    NDevSetDirty(dev);
    return n;
}

static s64 nigate_dev_pread(struct ntfs_device *dev, void *buf, s64 count, s64 offset) {
    NigateDevPriv *p = (NigateDevPriv *)dev->d_private;
    if (!p || !p->open) {
        errno = EBADF;
        return -1;
    }
    int64_t n = io_pread(&p->io, buf, count, offset);
    if (n < 0) {
        errno = EIO;
        return -1;
    }
    return n;
}

static s64 nigate_dev_pwrite(struct ntfs_device *dev, const void *buf, s64 count, s64 offset) {
    NigateDevPriv *p = (NigateDevPriv *)dev->d_private;
    if (!p || !p->open) {
        errno = EBADF;
        return -1;
    }
    if (NDevReadOnly(dev)) {
        errno = EROFS;
        return -1;
    }
    int64_t n = io_pwrite(&p->io, buf, count, offset);
    if (n < 0) {
        errno = EIO;
        return -1;
    }
    int64_t end = offset + n;
    if (end > p->size) p->size = end;
    NDevSetDirty(dev);
    return n;
}

static int nigate_dev_sync(struct ntfs_device *dev) {
    NigateDevPriv *p = (NigateDevPriv *)dev->d_private;
    if (!p || !p->open) {
        errno = EBADF;
        return -1;
    }
    if (io_sync(&p->io) != 0) {
        errno = EIO;
        return -1;
    }
    NDevClearDirty(dev);
    return 0;
}

static int nigate_dev_stat(struct ntfs_device *dev, struct stat *buf) {
    NigateDevPriv *p = (NigateDevPriv *)dev->d_private;
    if (!p || !p->open) {
        errno = EBADF;
        return -1;
    }
    memset(buf, 0, sizeof(*buf));
    buf->st_mode = S_IFBLK | 0644;
    buf->st_size = p->size;
    buf->st_blocks = (p->size + 511) / 512;
    buf->st_blksize = 512;
    return 0;
}

static int nigate_dev_ioctl(struct ntfs_device *dev, unsigned long request, void *argp) {
    (void)dev; (void)request; (void)argp;
    errno = ENOTTY;
    return -1;
}

static struct ntfs_device_operations nigate_ops = {
    .open = nigate_dev_open,
    .close = nigate_dev_close,
    .seek = nigate_dev_seek,
    .read = nigate_dev_read,
    .write = nigate_dev_write,
    .pread = nigate_dev_pread,
    .pwrite = nigate_dev_pwrite,
    .sync = nigate_dev_sync,
    .stat = nigate_dev_stat,
    .ioctl = nigate_dev_ioctl,
};

int nigate_ntfs_probe_boot(const NigateBlockIO *io, char *name_out, size_t name_cap) {
    if (!io || !io->pread) return -1;
    unsigned char buf[512];
    int64_t n = io->pread(io->ctx, buf, 512, 0);
    if (n < 512) return -1;
    /* OEM ID "NTFS    " at offset 3 */
    if (memcmp(buf + 3, "NTFS    ", 8) != 0) return 0;
    if (name_out && name_cap > 0) {
        name_out[0] = '\0';
    }
    return 1;
}

static void copy_err(char *err, size_t err_cap, const char *msg) {
    if (!err || err_cap == 0) return;
    snprintf(err, err_cap, "%s", msg ? msg : "unknown error");
}

NigateNTFSVolume *nigate_ntfs_mount(const NigateBlockIO *io, bool read_only, char *err, size_t err_cap) {
    if (!io || !io->pread) {
        copy_err(err, err_cap, "invalid block io");
        return NULL;
    }

    NigateNTFSVolume *wrap = calloc(1, sizeof(*wrap));
    if (!wrap) {
        copy_err(err, err_cap, "oom");
        return NULL;
    }
    wrap->io = *io;
    wrap->read_only = read_only;
    snprintf(wrap->name, sizeof(wrap->name), "NigateNTFS");

    NigateDevPriv *priv = calloc(1, sizeof(*priv));
    if (!priv) {
        free(wrap);
        copy_err(err, err_cap, "oom");
        return NULL;
    }
    priv->io = *io;

    struct ntfs_device *dev = ntfs_device_alloc("nigate-block", 0, &nigate_ops, priv);
    if (!dev) {
        free(priv);
        free(wrap);
        copy_err(err, err_cap, "ntfs_device_alloc failed");
        return NULL;
    }
    wrap->dev = dev;

    ntfs_mount_flags flags = read_only ? NTFS_MNT_RDONLY : 0;
    ntfs_volume *vol = ntfs_device_mount(dev, flags);
    if (!vol) {
        /* device_mount may free device on failure depending on version; free carefully */
        ntfs_device_free(dev);
        free(wrap);
        copy_err(err, err_cap, "ntfs_device_mount failed");
        return NULL;
    }
    wrap->vol = vol;
    /* vol_name 在 ntfs-3g 里是 char*（已转码的卷名） */
    if (vol->vol_name && vol->vol_name[0]) {
        snprintf(wrap->name, sizeof(wrap->name), "%s", vol->vol_name);
    }
    return wrap;
}

void nigate_ntfs_umount(NigateNTFSVolume *vol, bool force) {
    if (!vol) return;
    if (vol->vol) {
        ntfs_umount(vol->vol, force ? TRUE : FALSE);
        vol->vol = NULL;
        vol->dev = NULL; /* owned/freed by umount path */
    } else if (vol->dev) {
        ntfs_device_free(vol->dev);
        vol->dev = NULL;
    }
    free(vol);
}

bool nigate_ntfs_is_read_only(const NigateNTFSVolume *vol) {
    return vol ? vol->read_only : true;
}

const char *nigate_ntfs_volume_name(const NigateNTFSVolume *vol) {
    return vol ? vol->name : "NigateNTFS";
}

uint64_t nigate_ntfs_cluster_size(const NigateNTFSVolume *vol) {
    return vol && vol->vol ? (uint64_t)vol->vol->cluster_size : 4096;
}

uint64_t nigate_ntfs_total_clusters(const NigateNTFSVolume *vol) {
    return vol && vol->vol ? (uint64_t)vol->vol->nr_clusters : 0;
}

uint64_t nigate_ntfs_free_clusters(NigateNTFSVolume *vol) {
    if (!vol || !vol->vol) return 0;
    if (ntfs_volume_get_free_space(vol->vol) < 0) return 0;
    return (uint64_t)vol->vol->free_clusters;
}

uint64_t nigate_ntfs_root_mft(const NigateNTFSVolume *vol) {
    return FILE_root; /* 5 */
}

static void fill_info(ntfs_inode *ni, NigateNTFSItemInfo *out) {
    memset(out, 0, sizeof(*out));
    out->mft_no = ni->mft_no;
    out->mode = ni->flags; /* not posix mode; refine below */
    out->nlink = 1;
    out->size = ni->data_size;
    out->alloc_size = ni->allocated_size;
    out->is_dir = (ni->mrec->flags & MFT_RECORD_IS_DIRECTORY) ? true : false;
    out->is_file = !out->is_dir;
    out->is_symlink = false;
    /* times: NTFS 100ns since 1601 → approximate seconds via / 10000000 - offset if needed.
       For FSKit we mainly need monotonic values; use raw conversion helper if available. */
    out->atime_sec = (int64_t)(ni->last_access_time / 10000000ULL);
    out->mtime_sec = (int64_t)(ni->last_data_change_time / 10000000ULL);
    out->ctime_sec = (int64_t)(ni->last_mft_change_time / 10000000ULL);
    out->birth_sec = (int64_t)(ni->creation_time / 10000000ULL);
    if (out->is_dir) {
        out->mode = S_IFDIR | 0755;
    } else {
        out->mode = S_IFREG | 0644;
    }
}

int nigate_ntfs_item_info(NigateNTFSVolume *vol, uint64_t mft_no, NigateNTFSItemInfo *out) {
    if (!vol || !vol->vol || !out) return -EINVAL;
    ntfs_inode *ni = ntfs_inode_open(vol->vol, MK_MREF(mft_no, 0));
    if (!ni) return -errno;
    fill_info(ni, out);
    ntfs_inode_close(ni);
    return 0;
}

int nigate_ntfs_lookup(NigateNTFSVolume *vol, uint64_t dir_mft, const char *name, uint64_t *out_mft) {
    if (!vol || !vol->vol || !name || !out_mft) return -EINVAL;
    ntfs_inode *dir = ntfs_inode_open(vol->vol, MK_MREF(dir_mft, 0));
    if (!dir) return -errno;
    u64 ref = ntfs_inode_lookup_by_mbsname(dir, name);
    ntfs_inode_close(dir);
    if (ref == (u64)-1) return -ENOENT;
    *out_mft = MREF(ref);
    return 0;
}

typedef struct {
    NigateNTFSDirEntry *out;
    int max_count;
    int written;
    int64_t start_pos;
} FillCtx;

static int filldir_cb(void *dirent, const ntfschar *name, const int name_len,
                      const int name_type, const s64 pos,
                      const MFT_REF mref, const unsigned dt_type) {
    FillCtx *ctx = (FillCtx *)dirent;
    (void)name_type;
    if (pos < ctx->start_pos) return 0;
    if (ctx->written >= ctx->max_count) return 1; /* stop */

    NigateNTFSDirEntry *e = &ctx->out[ctx->written];
    memset(e, 0, sizeof(*e));
    e->mft_no = MREF(mref);
    e->next_pos = (uint64_t)(pos + 1);
    e->type = (uint8_t)dt_type;
    char *mb = NULL;
    if (ntfs_ucstombs(name, name_len, &mb, 0) < 0 || !mb) {
        snprintf(e->name, sizeof(e->name), "???");
    } else {
        snprintf(e->name, sizeof(e->name), "%s", mb);
        free(mb);
    }
    /* skip DOS short names type 2 if long name present — still include for simplicity */
    ctx->written += 1;
    return 0;
}

int nigate_ntfs_readdir(NigateNTFSVolume *vol, uint64_t dir_mft, int64_t *pos,
                        NigateNTFSDirEntry *out, int max_count, int *written) {
    if (!vol || !vol->vol || !pos || !out || !written || max_count <= 0) return -EINVAL;
    ntfs_inode *dir = ntfs_inode_open(vol->vol, MK_MREF(dir_mft, 0));
    if (!dir) return -errno;
    FillCtx ctx = { .out = out, .max_count = max_count, .written = 0, .start_pos = *pos };
    s64 cur = *pos;
    int rc = ntfs_readdir(dir, &cur, &ctx, filldir_cb);
    ntfs_inode_close(dir);
    *written = ctx.written;
    if (ctx.written > 0) {
        *pos = (int64_t)out[ctx.written - 1].next_pos;
    } else {
        *pos = cur;
    }
    if (rc < 0) return -errno;
    return 0;
}

int nigate_ntfs_read(NigateNTFSVolume *vol, uint64_t mft_no, int64_t offset,
                     void *buf, int64_t count, int64_t *got) {
    if (!vol || !vol->vol || !buf || !got) return -EINVAL;
    ntfs_inode *ni = ntfs_inode_open(vol->vol, MK_MREF(mft_no, 0));
    if (!ni) return -errno;
    ntfs_attr *na = ntfs_attr_open(ni, AT_DATA, AT_UNNAMED, 0);
    if (!na) {
        int e = errno;
        ntfs_inode_close(ni);
        return -e;
    }
    s64 n = ntfs_attr_pread(na, offset, count, buf);
    ntfs_attr_close(na);
    ntfs_inode_close(ni);
    if (n < 0) return -errno;
    *got = n;
    return 0;
}

int nigate_ntfs_write(NigateNTFSVolume *vol, uint64_t mft_no, int64_t offset,
                      const void *buf, int64_t count, int64_t *wrote) {
    if (!vol || !vol->vol || !buf || !wrote) return -EINVAL;
    if (vol->read_only) return -EROFS;
    ntfs_inode *ni = ntfs_inode_open(vol->vol, MK_MREF(mft_no, 0));
    if (!ni) return -errno;
    ntfs_attr *na = ntfs_attr_open(ni, AT_DATA, AT_UNNAMED, 0);
    if (!na) {
        int e = errno;
        ntfs_inode_close(ni);
        return -e;
    }
    s64 n = ntfs_attr_pwrite(na, offset, count, (void *)buf);
    ntfs_attr_close(na);
    if (n >= 0) ntfs_inode_mark_dirty(ni);
    ntfs_inode_close(ni);
    if (n < 0) return -errno;
    *wrote = n;
    return 0;
}

int nigate_ntfs_truncate(NigateNTFSVolume *vol, uint64_t mft_no, int64_t new_size) {
    if (!vol || !vol->vol) return -EINVAL;
    if (vol->read_only) return -EROFS;
    ntfs_inode *ni = ntfs_inode_open(vol->vol, MK_MREF(mft_no, 0));
    if (!ni) return -errno;
    ntfs_attr *na = ntfs_attr_open(ni, AT_DATA, AT_UNNAMED, 0);
    if (!na) {
        int e = errno;
        ntfs_inode_close(ni);
        return -e;
    }
    int rc = ntfs_attr_truncate(na, new_size);
    ntfs_attr_close(na);
    if (rc == 0) ntfs_inode_mark_dirty(ni);
    ntfs_inode_close(ni);
    return rc == 0 ? 0 : -errno;
}

int nigate_ntfs_create(NigateNTFSVolume *vol, uint64_t dir_mft, const char *name,
                       bool is_dir, uint64_t *out_mft) {
    if (!vol || !vol->vol || !name || !out_mft) return -EINVAL;
    if (vol->read_only) return -EROFS;
    ntfs_inode *dir = ntfs_inode_open(vol->vol, MK_MREF(dir_mft, 0));
    if (!dir) return -errno;
    ntfschar *uname = NULL;
    int uname_len = ntfs_mbstoucs(name, &uname);
    if (uname_len < 0) {
        ntfs_inode_close(dir);
        return -EINVAL;
    }
    mode_t type = is_dir ? (S_IFDIR | 0755) : (S_IFREG | 0644);
    ntfs_inode *ni = ntfs_create(dir, const_cpu_to_le32(0), uname, uname_len, type);
    free(uname);
    if (!ni) {
        int e = errno;
        ntfs_inode_close(dir);
        return -e;
    }
    *out_mft = ni->mft_no;
    ntfs_inode_close(ni);
    ntfs_inode_close(dir);
    return 0;
}

int nigate_ntfs_unlink(NigateNTFSVolume *vol, uint64_t dir_mft, uint64_t item_mft, const char *name) {
    if (!vol || !vol->vol || !name) return -EINVAL;
    if (vol->read_only) return -EROFS;
    ntfs_inode *dir = ntfs_inode_open(vol->vol, MK_MREF(dir_mft, 0));
    if (!dir) return -errno;
    ntfs_inode *ni = ntfs_inode_open(vol->vol, MK_MREF(item_mft, 0));
    if (!ni) {
        int e = errno;
        ntfs_inode_close(dir);
        return -e;
    }
    ntfschar *uname = NULL;
    int uname_len = ntfs_mbstoucs(name, &uname);
    if (uname_len < 0) {
        ntfs_inode_close(ni);
        ntfs_inode_close(dir);
        return -EINVAL;
    }
    int rc = ntfs_delete(vol->vol, name, ni, dir, uname, uname_len);
    free(uname);
    /* ntfs_delete closes inodes on success */
    if (rc) {
        ntfs_inode_close(ni);
        ntfs_inode_close(dir);
        return -errno;
    }
    return 0;
}

int nigate_ntfs_rename(NigateNTFSVolume *vol,
                       uint64_t src_dir, uint64_t item_mft, const char *src_name,
                       uint64_t dst_dir, const char *dst_name,
                       uint64_t over_mft) {
    if (!vol || !vol->vol || !src_name || !dst_name) return -EINVAL;
    if (vol->read_only) return -EROFS;
    /* minimal rename: link new name then unlink old (same-volume) */
    if (over_mft != 0) {
        int rc = nigate_ntfs_unlink(vol, dst_dir, over_mft, dst_name);
        if (rc) return rc;
    }
    int rc = nigate_ntfs_link(vol, item_mft, dst_dir, dst_name);
    if (rc) return rc;
    if (!(src_dir == dst_dir && strcmp(src_name, dst_name) == 0)) {
        rc = nigate_ntfs_unlink(vol, src_dir, item_mft, src_name);
    }
    return rc;
}

int nigate_ntfs_readlink(NigateNTFSVolume *vol, uint64_t mft_no, char *out, size_t out_cap) {
    if (!vol || !vol->vol || !out || out_cap == 0) return -EINVAL;
    /* Interix/symlink support is complex; return empty unsupported for non-reparse. */
    (void)mft_no;
    out[0] = '\0';
    return -EINVAL;
}

int nigate_ntfs_symlink(NigateNTFSVolume *vol, uint64_t dir_mft, const char *name,
                        const char *target, uint64_t *out_mft) {
    if (!vol || !vol->vol || !name || !target || !out_mft) return -EINVAL;
    if (vol->read_only) return -EROFS;
    ntfs_inode *dir = ntfs_inode_open(vol->vol, MK_MREF(dir_mft, 0));
    if (!dir) return -errno;
    ntfschar *uname = NULL;
    int uname_len = ntfs_mbstoucs(name, &uname);
    ntfschar *utarget = NULL;
    int utarget_len = ntfs_mbstoucs(target, &utarget);
    if (uname_len < 0 || utarget_len < 0) {
        free(uname); free(utarget);
        ntfs_inode_close(dir);
        return -EINVAL;
    }
    ntfs_inode *ni = ntfs_create_symlink(dir, const_cpu_to_le32(0), uname, uname_len, utarget, utarget_len);
    free(uname); free(utarget);
    if (!ni) {
        int e = errno;
        ntfs_inode_close(dir);
        return -e;
    }
    *out_mft = ni->mft_no;
    ntfs_inode_close(ni);
    ntfs_inode_close(dir);
    return 0;
}

int nigate_ntfs_link(NigateNTFSVolume *vol, uint64_t item_mft, uint64_t dir_mft, const char *name) {
    if (!vol || !vol->vol || !name) return -EINVAL;
    if (vol->read_only) return -EROFS;
    ntfs_inode *dir = ntfs_inode_open(vol->vol, MK_MREF(dir_mft, 0));
    if (!dir) return -errno;
    ntfs_inode *ni = ntfs_inode_open(vol->vol, MK_MREF(item_mft, 0));
    if (!ni) {
        int e = errno;
        ntfs_inode_close(dir);
        return -e;
    }
    ntfschar *uname = NULL;
    int uname_len = ntfs_mbstoucs(name, &uname);
    if (uname_len < 0) {
        ntfs_inode_close(ni);
        ntfs_inode_close(dir);
        return -EINVAL;
    }
    int rc = ntfs_link(ni, dir, uname, uname_len);
    free(uname);
    ntfs_inode_close(ni);
    ntfs_inode_close(dir);
    return rc == 0 ? 0 : -errno;
}

int nigate_ntfs_sync(NigateNTFSVolume *vol) {
    if (!vol || !vol->vol) return -EINVAL;
    if (vol->dev && vol->dev->d_ops && vol->dev->d_ops->sync) {
        return vol->dev->d_ops->sync(vol->dev) == 0 ? 0 : -errno;
    }
    return 0;
}
