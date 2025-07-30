#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/usb.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
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

static struct usb_device_id tala_table[] = {
    {USB_DEVICE(VENDOR_ID, PRODUCT_ID)},
    {USB_DEVICE_INFO(USB_CLASS, SUBCLASS, PROTOCOL)},
    {} /* Terminating entry */
};

MODULE_DEVICE_TABLE(usb, tala_table);

static struct usb_device *device;
static unsigned char *bulk_buf;
static DEFINE_MUTEX(device_mutex);

static int tala_open(struct inode *i, struct file *f) {
    if (!mutex_trylock(&device_mutex)) {
        pr_err("tala: Device is busy.\n");
        return -EBUSY;
    }
    pr_info("tala: Device opened.\n");
    return 0;
}

static int tala_close(struct inode *i, struct file *f) {
    mutex_unlock(&device_mutex);
    pr_info("tala: Device closed.\n");
    return 0;
}

static ssize_t tala_read(struct file *f, char __user *buf, size_t count, loff_t *off) {
    int ret, actual_length;

    if (count > PACKET_SIZE) {
        pr_err("tala_read: Requested read size exceeds buffer limit.\n");
        return -EINVAL;
    }

    /* Read data from the bulk IN endpoint */
    ret = usb_bulk_msg(device, usb_rcvbulkpipe(device, BULK_IN_ENDP), bulk_buf,
                       count, &actual_length, TIMEOUT_MS);

    if (ret) {
        pr_err("tala_read: usb_bulk_msg failed (error %d).\n", ret);
        return ret;
    }

    if (copy_to_user(buf, bulk_buf, actual_length)) {
        pr_err("tala_read: Failed to copy data to user space.\n");
        return -EFAULT;
    }

    pr_info("tala_read: Read %d bytes successfully.\n", actual_length);
    return actual_length;
}

static ssize_t tala_write(struct file *f, const char __user *buf, size_t count, loff_t *off) {
    int ret, actual_length;

    if (count > PACKET_SIZE) {
        pr_err("tala_write: Requested write size exceeds buffer limit.\n");
        return -EINVAL;
    }

    if (copy_from_user(bulk_buf, buf, count)) {
        pr_err("tala_write: Failed to copy data from user space.\n");
        return -EFAULT;
    }

    /* Write data to the bulk OUT endpoint */
    ret = usb_bulk_msg(device, usb_sndbulkpipe(device, BULK_OUT_ENDP), bulk_buf,
                       count, &actual_length, TIMEOUT_MS);

    if (ret) {
        pr_err("tala_write: usb_bulk_msg failed (error %d).\n", ret);
        return ret;
    }

    pr_info("tala_write: Wrote %d bytes successfully.\n", actual_length);
    return actual_length;
}

static struct file_operations tala_fops = {
    .owner   = THIS_MODULE,
    .open    = tala_open,
    .release = tala_close,
    .read    = tala_read,
    .write   = tala_write,
};

static struct usb_class_driver tala_class = {
    .name = "usb/skel%d",
    .fops = &tala_fops,
    .mode = 0660, /* Allow owner and group to read/write */
};

static int tala_probe(struct usb_interface *interface, const struct usb_device_id *id) {
    int ret;

    pr_info("tala: Device plugged in.\n");

    device = interface_to_usbdev(interface);
    bulk_buf = kzalloc(PACKET_SIZE, GFP_KERNEL);
    if (!bulk_buf) {
        pr_err("tala_probe: Failed to allocate memory for bulk buffer.\n");
        return -ENOMEM;
    }

    ret = usb_register_dev(interface, &tala_class);
    if (ret) {
        pr_err("tala_probe: Failed to register device (error %d).\n", ret);
        kfree(bulk_buf);
        bulk_buf = NULL;
    } else {
        pr_info("tala: Device registered successfully (minor %d).\n", interface->minor);
    }

    return ret;
}

static void tala_disconnect(struct usb_interface *interface) {
    usb_deregister_dev(interface, &tala_class);

    if (bulk_buf) {
        memset(bulk_buf, 0, PACKET_SIZE); /* Clear sensitive data */
        kfree(bulk_buf);
        bulk_buf = NULL;
    }

    pr_info("tala: Device disconnected.\n");
}

static struct usb_driver tala_driver = {
    .name       = "tala",
    .id_table   = tala_table,
    .probe      = tala_probe,
    .disconnect = tala_disconnect,
};

static int __init tala_init(void) {
    int ret;

    pr_info("tala: Initializing driver.\n");
    ret = usb_register(&tala_driver);
    if (ret) {
        pr_err("tala_init: usb_register failed (error %d).\n", ret);
    }

    return ret;
}

static void __exit tala_exit(void) {
    pr_info("tala: Exiting driver.\n");
    usb_deregister(&tala_driver);
}

module_init(tala_init);
module_exit(tala_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Security Research");
MODULE_DESCRIPTION("USB driver for mass storage device emulation");
