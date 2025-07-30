#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/usb.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/usb/composite.h>
#include <linux/mutex.h>

#define VENDOR_ID  0x058f /* Alcor Micro Corp. */
#define PRODUCT_ID 0x6387 /* Flash Drive */
#define USB_CLASS  8      /* Mass Storage */
#define SUBCLASS   6      /* SCSI */
#define PROTOCOL   80     /* Bulk-Only */

#define BULK_OUT_ENDP 0x01
#define BULK_IN_ENDP  0x82
#define PACKET_SIZE   512
#define TIMEOUT_MS    5000 /* Timeout in milliseconds */

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Mujtaba Asim, Improved by Assistant");
MODULE_DESCRIPTION("Secure USB driver with g_mass_storage support.");
MODULE_VERSION("0.0.4");

static struct usb_device_id tala_table[] = {
    {USB_DEVICE(VENDOR_ID, PRODUCT_ID)},
    {USB_DEVICE_INFO(USB_CLASS, SUBCLASS, PROTOCOL)},
    {} /* Terminating entry */
};

MODULE_DEVICE_TABLE(usb, tala_table);

static struct usb_device *device;
static unsigned char *bulk_buf;
static DEFINE_MUTEX(device_mutex);

static struct usb_gadget *gadget;

static struct usb_composite_driver composite_driver;

static struct usb_configuration config;

static struct usb_gadget_driver gadget_driver = {
    .function   = "gadget_mass_storage",
    .driver     = {
        .name = "usb_mass_storage_emulator",
        .owner = THIS_MODULE,
    },
};

// Mass storage device memory buffer
static unsigned char *storage_buffer;
#define STORAGE_SIZE 1024 * 1024 /* 1MB for example */

/* Read data from the storage buffer */
static ssize_t tala_read(struct file *f, char __user *buf, size_t count, loff_t *off)
{
    int ret;

    if (count > STORAGE_SIZE) {
        pr_err("tala_read: Requested size exceeds storage limit.\n");
        return -EINVAL;
    }

    if (copy_to_user(buf, storage_buffer, count)) {
        pr_err("tala_read: Failed to copy data to user space.\n");
        return -EFAULT;
    }

    pr_info("tala_read: Read %ld bytes from storage.\n", count);
    return count;
}

/* Write data to the storage buffer */
static ssize_t tala_write(struct file *f, const char __user *buf, size_t count, loff_t *off)
{
    if (count > STORAGE_SIZE) {
        pr_err("tala_write: Requested size exceeds storage limit.\n");
        return -EINVAL;
    }

    if (copy_from_user(storage_buffer, buf, count)) {
        pr_err("tala_write: Failed to copy data from user space.\n");
        return -EFAULT;
    }

    pr_info("tala_write: Wrote %ld bytes to storage.\n", count);
    return count;
}

/* Open the device */
static int tala_open(struct inode *i, struct file *f) {
    if (!mutex_trylock(&device_mutex)) {
        pr_err("tala: Device is busy.\n");
        return -EBUSY;
    }
    pr_info("tala: Device opened.\n");
    return 0;
}

/* Close the device */
static int tala_close(struct inode *i, struct file *f) {
    mutex_unlock(&device_mutex);
    pr_info("tala: Device closed.\n");
    return 0;
}

static struct file_operations tala_fops = {
    .owner   = THIS_MODULE,
    .open    = tala_open,
    .release = tala_close,
    .read    = tala_read,
    .write   = tala_write,
};

/* Define mass storage endpoints and configuration */
static struct usb_endpoint_descriptor bulk_in_desc = {
    .bEndpointAddress = BULK_IN_ENDP,
    .bmAttributes = USB_ENDPOINT_XFER_BULK,
    .wMaxPacketSize = cpu_to_le16(PACKET_SIZE),
};

static struct usb_endpoint_descriptor bulk_out_desc = {
    .bEndpointAddress = BULK_OUT_ENDP,
    .bmAttributes = USB_ENDPOINT_XFER_BULK,
    .wMaxPacketSize = cpu_to_le16(PACKET_SIZE),
};

static struct usb_interface_descriptor interface_desc = {
    .bNumEndpoints = 2,
    .bInterfaceClass = USB_CLASS_MASS_STORAGE,
    .bInterfaceSubClass = SUBCLASS,
    .bInterfaceProtocol = PROTOCOL,
    .endpoint = (struct usb_endpoint_descriptor[]) {
        bulk_in_desc,
        bulk_out_desc,
    },
};

/* Mass Storage Driver Setup */
static int __init tala_init(void)
{
    int ret;

    pr_info("tala: Initializing USB gadget with g_mass_storage.\n");

    storage_buffer = kmalloc(STORAGE_SIZE, GFP_KERNEL);
    if (!storage_buffer) {
        pr_err("tala_init: Failed to allocate memory for storage buffer.\n");
        return -ENOMEM;
    }

    /* Initialize gadget driver */
    ret = usb_gadget_register_driver(&gadget_driver);
    if (ret) {
        pr_err("tala_init: usb_gadget_register_driver failed (error %d).\n", ret);
        kfree(storage_buffer);
        return ret;
    }

    pr_info("tala: USB gadget initialized.\n");

    return 0;
}

static void __exit tala_exit(void)
{
    pr_info("tala: Exiting USB gadget driver.\n");

    usb_gadget_unregister_driver(&gadget_driver);
    kfree(storage_buffer);

    pr_info("tala: Exiting driver.\n");
}

module_init(tala_init);
module_exit(tala_exit);
