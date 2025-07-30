import bluetooth
import time
import logging
import sys
import signal
import socket
import os
import platform
import threading
import configparser
import tkinter as tk
from tkinter import messagebox
from datetime import datetime
import asyncio

# Configure logging
logging.basicConfig(
    filename="bluetooth_tool.log",
    level=logging.DEBUG,  # Default to DEBUG for more verbosity
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger()

# Graceful exit handler
def signal_handler(sig, frame):
    print("\nGracefully exiting the Bluetooth tool.")
    logger.info("Tool was terminated by user.")
    sys.exit(0)

# Attach the signal handler for graceful exit
signal.signal(signal.SIGINT, signal_handler)

# Configuration handler
class Config:
    def __init__(self):
        self.config = configparser.ConfigParser()
        self.config.read("settings.ini")
        
    def get(self, section, key):
        try:
            return self.config.get(section, key)
        except KeyError as e:
            logger.error(f"KeyError: {e} - Missing in config file.")
            return None

    def set(self, section, key, value):
        self.config.set(section, key, value)
        with open("settings.ini", "w") as configfile:
            self.config.write(configfile)

# Scan Bluetooth devices
async def scan_devices():
    """Scan for nearby Bluetooth devices and return the list of devices with IPs if available."""
    logger.info("Scanning for Bluetooth devices...")
    nearby_devices = bluetooth.discover_devices(duration=8, lookup_names=True, lookup_uuids=True, flush_cache=True)
    
    devices_info = []
    
    if not nearby_devices:
        logger.warning("No Bluetooth devices found.")
        return devices_info
    else:
        logger.info(f"Found {len(nearby_devices)} Bluetooth devices.")
        for addr, name in nearby_devices:
            try:
                device_ip = await get_device_ip(addr)
                device_info = {"address": addr, "name": name, "ip": device_ip}
                devices_info.append(device_info)
            except Exception as e:
                logger.warning(f"Could not retrieve IP for {addr}: {e}")
    
    return devices_info

async def get_device_ip(device_address):
    """Try to get the IP address of the Bluetooth device (based on network services)."""
    try:
        host_ip = socket.gethostbyname(device_address)
        return host_ip
    except socket.gaierror:
        return "Not Available"

# Connect to a Bluetooth device (simulated)
async def connect_to_device(device_address):
    """Attempt to connect to a Bluetooth device using its address."""
    try:
        sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
        sock.connect((device_address, 1))  # RFCOMM channel 1
        logger.info(f"Connected to device: {device_address}")
        return sock
    except bluetooth.BluetoothError as e:
        logger.error(f"Failed to connect to {device_address}: {e}")
        return None

async def send_data(sock, message):
    """Send data to the connected Bluetooth device."""
    try:
        sock.send(message)
        logger.info(f"Sent message: {message}")
    except bluetooth.BluetoothError as e:
        logger.error(f"Failed to send data: {e}")

async def disconnect_device(sock):
    """Disconnect from the Bluetooth device."""
    try:
        sock.close()
        logger.info("Disconnected from the device.")
    except bluetooth.BluetoothError as e:
        logger.error(f"Failed to disconnect: {e}")

# Block the device IP for a certain duration using the system firewall
async def block_ip(ip_address, duration=30):
    """Simulate blocking a device by IP using system firewall tools."""
    system = platform.system().lower()
    try:
        if system == 'linux':
            os.system(f"sudo iptables -A INPUT -s {ip_address} -j DROP")
            await asyncio.sleep(duration)
            os.system(f"sudo iptables -D INPUT -s {ip_address} -j DROP")
        elif system == 'darwin':  # macOS
            os.system(f"sudo pfctl -t blocklist -T add {ip_address}")
            await asyncio.sleep(duration)
            os.system(f"sudo pfctl -t blocklist -T delete {ip_address}")
        elif system == 'windows':
            os.system(f"netsh advfirewall firewall add rule name=\"Block {ip_address}\" dir=in action=block remoteip={ip_address}")
            await asyncio.sleep(duration)
            os.system(f"netsh advfirewall firewall delete rule name=\"Block {ip_address}\"")
        else:
            logger.error(f"Unsupported OS: {system}")
    except Exception as e:
        logger.error(f"Error blocking IP {ip_address}: {e}")

# Function to perform persistent monitoring and blocking
async def persistent_monitoring(devices_info, block_duration=30, gui_update_callback=None):
    """Monitor and interact with Bluetooth devices persistently."""
    while True:
        devices = await scan_devices()
        
        if devices:
            for device in devices:
                ip = device['ip']
                if ip != "Not Available":
                    await block_ip(ip, block_duration)
                    if gui_update_callback:
                        gui_update_callback(f"Blocked IP: {ip}")

            for device in devices:
                device_address = device['address']
                sock = await connect_to_device(device_address)
                
                if sock:
                    await send_data(sock, "Hello, this is an ethical penetration test message.")
                    await asyncio.sleep(10)  # Keep the connection alive for 10 seconds
                    await disconnect_device(sock)
                await asyncio.sleep(2)
        
        await asyncio.sleep(30)

# Function to handle the GUI
class BluetoothToolGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Bluetooth Persistence and Blocking Tool")
        self.root.geometry("500x300")
        
        self.label = tk.Label(self.root, text="Bluetooth Tool", font=("Helvetica", 16))
        self.label.pack(pady=20)
        
        self.start_button = tk.Button(self.root, text="Start Monitoring", command=self.start_monitoring)
        self.start_button.pack(pady=10)
        
        self.status_label = tk.Label(self.root, text="Status: Idle", font=("Helvetica", 12))
        self.status_label.pack(pady=10)
        
        self.log_text = tk.Text(self.root, height=8, width=50)
        self.log_text.pack(pady=10)
        self.log_text.config(state=tk.DISABLED)

    def update_log(self, message):
        """Update the log area in the GUI."""
        self.log_text.config(state=tk.NORMAL)
        self.log_text.insert(tk.END, message + '\n')
        self.log_text.config(state=tk.DISABLED)
        self.log_text.yview(tk.END)

    def start_monitoring(self):
        """Start monitoring in a separate thread to avoid blocking the GUI."""
        self.status_label.config(text="Status: Monitoring...")
        threading.Thread(target=self.monitor_devices, daemon=True).start()

    def monitor_devices(self):
        """Wrapper for persistent monitoring in a separate thread."""
        config = Config()
        block_duration = int(config.get("settings", "block_duration") or 30)
        try:
            devices_info = asyncio.run(scan_devices())
            if not devices_info:
                self.update_log("No devices found.")
                return

            self.update_log("Starting monitoring and blocking devices...")
            asyncio.run(persistent_monitoring(devices_info, block_duration, self.update_log))

        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            self.update_log(f"Error: {e}")

# Main function to set up the GUI
def main():
    root = tk.Tk()
    gui = BluetoothToolGUI(root)
    root.mainloop()

if __name__ == "__main__":
    main()
