# GhostWhisper Suite - Module Standards & Consistency Guide

**Version:** 1.6.1  
**Last Updated:** 2026-02-23  
**For Raven. 2017 — ∞**

## Overview

This document defines code standards, consistency requirements, and best practices for all modules in the GhostWhisper Suite. All developers and contributors should follow these guidelines to ensure fluid, maintainable, and secure code.

---

## 1. General Principles

### 1.1 Code Quality Objectives
- **Readability**: Code should be clear and self-documenting
- **Maintainability**: Future developers should understand intent quickly
- **Reliability**: Proper error handling and validation throughout
- **Security**: No hardcoded credentials, sensitive data protection
- **Compatibility**: Cross-platform and version-compatible where possible

### 1.2 Documentation Requirements
- Every module must include:
  - Header docstring with version and date
  - Function/method documentation with purpose and parameters
  - Comments for complex logic
  - Error handling explanations

---

## 2. PowerShell Module Standards

### 2.1 Header Format
```powershell
# ModuleName.ps1
# Brief description of purpose
# Part of WhisperSuite: GhostWhisper Edition v1.6.1
#
# Functions: Function1, Function2, Function3
# Dependencies: Module1, Module2
# Last Updated: 2026-02-23

param()

$ModuleVersion = "1.6.1"
```

### 2.2 Function Standards
```powershell
function Invoke-GhostOperation {
    <#
    .SYNOPSIS
        Brief description of what the function does
    
    .DESCRIPTION
        Detailed description including purpose, behavior, and side effects
    
    .PARAMETER Target
        Description of the Target parameter
    
    .PARAMETER Verbose
        Enable verbose output
    
    .OUTPUTS
        Describe what the function returns
    
    .EXAMPLE
        Invoke-GhostOperation -Target "server.com"
    
    .NOTES
        Security considerations, version info, author notes
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Target,
        
        [switch]$Verbose
    )
    
    Write-Verbose "[*] Starting operation on $Target"
    
    try {
        # Operation logic
        return $result
    }
    catch {
        Write-Error "Operation failed: $_"
        return $null
    }
}
```

### 2.3 Logging Standards
```powershell
# Use structured logging format
Write-Host "[+] Success message" -ForegroundColor Green
Write-Host "[*] Info message" -ForegroundColor Gray
Write-Host "[!] Warning message" -ForegroundColor Yellow
Write-Host "[X] Error message" -ForegroundColor Red

# Log to file when appropriate
Add-Content -Path $logFile -Value "[$timestamp] [ComponentName] Message"
```

### 2.4 Error Handling
```powershell
try {
    $result = Perform-Operation
    if (-not $result) {
        throw "Operation returned null"
    }
}
catch {
    $errorMsg = $_.Exception.Message
    Write-GhostLog "Error in module: $errorMsg" "ERROR"
    return $false
}
finally {
    # Cleanup code
    Clean-Resources
}
```

---

## 3. Python Module Standards

### 3.1 Header Format
```python
"""
ModuleName.py - Brief description
Part of WhisperSuite: GhostWhisper Edition v1.6.1

Functions: function1, function2, function3
Dependencies: requests, paramiko
Last Updated: 2026-02-23

🕊️ For Raven. 2017 — ∞
"""

import os
import sys
import logging
from typing import Optional, List, Dict

__version__ = "1.6.1"
__author__ = "GhostWhisper"

logger = logging.getLogger(__name__)
```

### 3.2 Function Standards
```python
def ghost_operation(target: str, timeout: int = 30) -> Optional[Dict]:
    """
    Perform ghost operation on target.
    
    Args:
        target (str): Target hostname or IP address
        timeout (int): Operation timeout in seconds (default: 30)
    
    Returns:
        Optional[Dict]: Operation results or None if failed
    
    Raises:
        ValueError: If target is invalid
        TimeoutError: If operation exceeds timeout
    
    Examples:
        >>> result = ghost_operation("192.168.1.1", timeout=60)
        >>> if result:
        ...     print(f"Success: {result['status']}")
    """
    if not isinstance(target, str) or not target:
        raise ValueError("target must be non-empty string")
    
    logger.debug(f"Starting operation on {target}")
    
    try:
        result = _perform_operation(target, timeout)
        logger.info(f"Operation successful on {target}")
        return result
    except TimeoutError:
        logger.error(f"Operation timeout on {target}")
        raise
    except Exception as e:
        logger.error(f"Operation failed: {e}")
        return None
```

### 3.3 Logging Standards
```python
import logging

# Configure at module level
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - [%(name)s] %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# Use appropriate levels
logger.debug("Debug information")
logger.info("Informational message")
logger.warning("Warning message")
logger.error("Error message")
logger.critical("Critical issue")
```

### 3.4 Type Hints & Validation
```python
from typing import Optional, List, Dict, Tuple
from pathlib import Path

def process_files(
    directory: str,
    pattern: str = "*.txt",
    recursive: bool = False
) -> Tuple[int, List[str]]:
    """
    Process files matching pattern.
    
    Returns:
        Tuple of (success_count, file_list)
    """
    path = Path(directory)
    if not path.exists():
        raise ValueError(f"Directory not found: {directory}")
    
    # Use pathlib for cross-platform compatibility
    if recursive:
        files = list(path.rglob(pattern))
    else:
        files = list(path.glob(pattern))
    
    return len(files), [str(f) for f in files]
```

### 3.5 Error Handling
```python
try:
    result = perform_operation()
except ValueError as e:
    logger.error(f"Invalid input: {e}")
    sys.exit(1)
except TimeoutError:
    logger.error("Operation timed out")
    sys.exit(2)
except Exception as e:
    logger.error(f"Unexpected error: {e}", exc_info=True)
    sys.exit(3)
finally:
    # Cleanup resources
    close_connections()
```

---

## 4. Go Module Standards

### 4.1 Header Format
```go
package main

import (
    "fmt"
    "log"
)

const (
    Version = "1.6.1"
    AppName = "GhostTool"
)

/*
GhostTool - Brief description
Part of WhisperSuite: GhostWhisper Edition

Functions: function1, function2
Dependencies: golang.org/x/crypto/ssh
Last Updated: 2026-02-23

🕊️ For Raven. 2017 — ∞
*/

func init() {
    log.SetFlags(log.LstdFlags | log.Lshortfile)
}
```

### 4.2 Function Standards
```go
// GhostOperation performs operation on target
// Returns result string or error if operation fails
func GhostOperation(target string, timeout int) (string, error) {
    if target == "" {
        return "", errors.New("target cannot be empty")
    }
    
    log.Printf("[*] Starting operation on %s", target)
    
    result, err := performOperation(target, timeout)
    if err != nil {
        log.Printf("[!] Operation failed: %v", err)
        return "", err
    }
    
    log.Printf("[+] Operation successful on %s", target)
    return result, nil
}
```

### 4.3 Logging Standards
```go
log.Printf("[*] Info message: %v", variable)
log.Printf("[+] Success: operation completed")
log.Printf("[!] Warning: condition detected")
log.Printf("[X] Error: %v", err)

// For critical errors with line info
log.Fatalf("[X] Critical: %v", err)
```

### 4.4 Error Handling
```go
result, err := SomeOperation()
if err != nil {
    if errors.Is(err, ErrTimeout) {
        log.Printf("[!] Operation timeout: %v", err)
        return nil, err
    }
    log.Printf("[X] Operation failed: %v", err)
    return nil, fmt.Errorf("failed to complete operation: %w", err)
}
```

### 4.5 Best Practices
- Always use error returns instead of panics (except init)
- Use defer for resource cleanup
- Implement context.Context for timeouts
- Use io package instead of deprecated io/ioutil
- Load configuration from environment variables, not hardcoded

---

## 5. Security Standards

### 5.1 Credentials & Secrets
- **NEVER** hardcode passwords, API keys, or authentication tokens
- Load from environment variables: `os.Getenv()` (Go), `os.getenv()` (Python)
- Use PowerShell SecureString for sensitive data
- Validate and sanitize all inputs

### 5.2 File Operations
```python
# Python - Use pathlib for cross-platform paths
from pathlib import Path
file_path = Path(directory) / filename
with open(file_path, 'r') as f:
    content = f.read()

# Go - Use filepath package
import "path/filepath"
path := filepath.Join(directory, filename)

# PowerShell - Use Join-Path
$path = Join-Path $directory $filename
```

### 5.3 Logging Sensitive Data
```python
# BAD
logger.info(f"Connecting as {username}:{password}")

# GOOD
logger.info(f"Connecting as user: {username}")
logger.debug(f"Password length: {len(password)} chars")
```

### 5.4 Input Validation
```python
def validate_target(target: str) -> bool:
    """Validate target format"""
    if not target or not isinstance(target, str):
        return False
    
    # Remove whitespace
    target = target.strip()
    
    # Validate format (IP or hostname)
    if not re.match(r'^[a-zA-Z0-9\-\.]+$', target):
        return False
    
    return True
```

---

## 6. Testing Standards

### 6.1 Unit Tests
```python
import unittest

class TestGhostOperations(unittest.TestCase):
    
    def setUp(self):
        """Initialize test fixtures"""
        self.target = "127.0.0.1"
    
    def test_valid_operation(self):
        """Test operation with valid target"""
        result = ghost_operation(self.target)
        self.assertIsNotNone(result)
    
    def test_invalid_target(self):
        """Test operation with invalid target"""
        with self.assertRaises(ValueError):
            ghost_operation("")
    
    def tearDown(self):
        """Clean up after tests"""
        pass

if __name__ == '__main__':
    unittest.main()
```

### 6.2 Go Tests
```go
package main

import (
    "testing"
)

func TestGhostOperation(t *testing.T) {
    result, err := GhostOperation("test-target", 30)
    if err != nil {
        t.Fatalf("Expected success, got error: %v", err)
    }
    if result == "" {
        t.Error("Expected non-empty result")
    }
}

func TestInvalidTarget(t *testing.T) {
    _, err := GhostOperation("", 30)
    if err == nil {
        t.Error("Expected error for empty target")
    }
}
```

---

## 7. Version & Changelog Standards

### 7.1 Versioning Scheme
Use semantic versioning: `MAJOR.MINOR.PATCH`
- `MAJOR`: Breaking changes or major features
- `MINOR`: New features or enhancements
- `PATCH`: Bug fixes and improvements

Current: **v1.6.1**

### 7.2 Changelog Entry Format
```markdown
## [v1.6.1] – 2026-02-23
### 🔧 Code Quality & Modernization
- **ModuleName.py**: Description of changes

### 🐛 Bug Fixes
- Fixed issue description

### 🛡️ Security Improvements
- Security fix description
```

---

## 8. Module Integration Checklist

Before releasing a module, ensure:

- [ ] Follows header format for language
- [ ] All functions documented with docstrings/comments
- [ ] Error handling implemented for all operations
- [ ] No hardcoded credentials or secrets
- [ ] Type hints present (Python/Go)
- [ ] Logging configured appropriately
- [ ] Cross-platform compatibility verified
- [ ] Dependencies listed and documented
- [ ] Unit tests written and passing
- [ ] Changelog entry added
- [ ] Version number updated
- [ ] Code reviewed by team

---

## 9. Common Patterns

### 9.1 Configuration Management
```python
# Python
import os
from configparser import ConfigParser

config = ConfigParser()
config.read("config.ini")

# Environment variable fallback
api_key = os.getenv("GHOST_API_KEY", config.get("api", "key", fallback=None))
```

```powershell
# PowerShell
$config = @{
    ApiKey = $env:GHOST_API_KEY
    Timeout = 30
}

if (-not $config.ApiKey) {
    Write-Warning "GHOST_API_KEY environment variable not set"
}
```

### 9.2 Async Operations
```python
# Python with asyncio
import asyncio

async def async_operation(target: str):
    """Perform async operation"""
    try:
        result = await asyncio.wait_for(
            perform_operation(target),
            timeout=30.0
        )
        return result
    except asyncio.TimeoutError:
        logger.error(f"Operation timeout on {target}")
        return None
```

### 9.3 Logging with Context
```python
import logging

class GhostLogger:
    def __init__(self, module_name: str):
        self.logger = logging.getLogger(module_name)
        self.context = {}
    
    def info(self, msg: str, **kwargs):
        """Log with context"""
        context_str = " | ".join(f"{k}={v}" for k, v in kwargs.items())
        full_msg = f"{msg} | {context_str}" if context_str else msg
        self.logger.info(full_msg)
```

---

## 10. Code Review Criteria

Reviewers should verify:

1. **Correctness**: Does the code work as intended?
2. **Security**: Are there any security vulnerabilities?
3. **Standards**: Does it follow these guidelines?
4. **Performance**: Are there obvious performance issues?
5. **Documentation**: Is it clear and complete?
6. **Testing**: Are tests present and comprehensive?
7. **Compatibility**: Does it work across platforms/versions?

---

## 11. Quick Reference

### Logging Levels
```
DEBUG   - Detailed diagnostic information
INFO    - Confirmation that things are working
WARNING - Warning about potential issues
ERROR   - Serious problem, functionality may be impaired
CRITICAL- Very serious, program may not continue
```

### Status Indicators
```
[*] General info/progress
[+] Success/completion
[!] Warning/caution
[X] Error/failure
[i] Additional information
[~] Status/state change
```

### Common Abbreviations
```
pwd   - Current directory
msg   - Message
err   - Error
res   - Result
cfg   - Configuration
srv   - Server
conn  - Connection
auth  - Authentication
sec   - Security
```

---

## Conclusion

Maintaining these standards ensures:
- **Code Quality**: Easier to read, understand, and maintain
- **Security**: Consistent security practices throughout
- **Reliability**: Better error handling and edge case coverage
- **Compatibility**: Works across different systems and versions
- **Collaboration**: Team members understand expectations

**Last Updated:** 2026-02-23  
**For Raven. 2017 — ∞**
