"""
GhostMemory - Conversation and Operation Memory for GhostWhisper Suite
Persistent storage for AI interactions and operational history

💝 Support Development: https://buy.stripe.com/28EbJ1f7ceo3ckyeES5kk00
"""

import os
import json
import hashlib
import sqlite3
import threading
from datetime import datetime
from typing import Dict, List, Optional, Any
from pathlib import Path
from dataclasses import dataclass, asdict

# ============================================================================
# DATA CLASSES
# ============================================================================

@dataclass
class MemoryEntry:
    """Single memory entry"""
    entry_id: str
    role: str  # user, ghost, system
    content: str
    timestamp: str
    ghost_tag: str
    context: str = ""
    metadata: Dict = None
    
    def to_dict(self) -> Dict:
        return asdict(self)


@dataclass 
class OperationLog:
    """Operation execution log"""
    operation_id: str
    operation_type: str
    target: str
    parameters: Dict
    result: str
    success: bool
    duration_ms: int
    ghost_tag: str
    timestamp: str


# ============================================================================
# GHOST MEMORY - FILE-BASED
# ============================================================================

class GhostMemory:
    """
    File-based conversation memory for GhostWhisper operations.
    Compatible with AICorePortable's GhostMemory interface.
    """
    
    def __init__(self, log_path: str = "operations/ai_session.log"):
        self.log_path = log_path
        os.makedirs(os.path.dirname(self.log_path), exist_ok=True) if os.path.dirname(self.log_path) else None
        self._last_user = None
        self._lock = threading.Lock()
    
    def save(self, role: str, message: str):
        """Save a message - compatible with AICorePortable interface"""
        role_lower = role.lower()
        
        with self._lock:
            if role_lower == "user":
                self._last_user = message
            elif role_lower == "ghost" and self._last_user:
                self.save_interaction(self._last_user, message)
                self._last_user = None
    
    def save_interaction(self, user_input: str, ai_response: str):
        """Save a complete interaction pair"""
        with self._lock:
            try:
                with open(self.log_path, "a", encoding="utf-8") as f:
                    timestamp = datetime.now().isoformat()
                    f.write(f"[{timestamp}]\n")
                    f.write(f"User: {user_input}\n")
                    f.write(f"Ghost: {ai_response}\n\n")
            except Exception as e:
                pass  # Silent fail for stealth
    
    def load_recent_history(self, limit: int = 10) -> List[str]:
        """Load recent conversation history"""
        if not os.path.exists(self.log_path):
            return []
        
        try:
            with open(self.log_path, "r", encoding="utf-8") as f:
                lines = f.readlines()
        except:
            return []
        
        # Parse into structured turns
        turns = []
        current = {}
        
        for line in lines:
            line = line.strip()
            if line.startswith("User:"):
                current["user"] = line.replace("User:", "").strip()
            elif line.startswith("Ghost:"):
                current["ghost"] = line.replace("Ghost:", "").strip()
                if "user" in current:
                    turns.append(current)
                current = {}
        
        # Get last N turns
        turns = turns[-limit:]
        
        # Format as list of strings
        history = []
        for t in turns:
            history.append(f"User: {t.get('user', '')}")
            history.append(f"Ghost: {t.get('ghost', '')}")
        
        return history
    
    def search(self, query: str, limit: int = 10) -> List[Dict]:
        """Search conversation history"""
        if not os.path.exists(self.log_path):
            return []
        
        try:
            with open(self.log_path, "r", encoding="utf-8") as f:
                content = f.read()
        except:
            return []
        
        results = []
        query_lower = query.lower()
        
        # Split into conversation blocks
        blocks = content.split("\n\n")
        
        for block in blocks:
            if query_lower in block.lower():
                results.append({
                    "content": block.strip(),
                    "match": query
                })
                if len(results) >= limit:
                    break
        
        return results
    
    def clear(self):
        """Clear all history"""
        with self._lock:
            if os.path.exists(self.log_path):
                try:
                    os.remove(self.log_path)
                except:
                    pass


# ============================================================================
# GHOST MEMORY DB - SQLITE-BASED
# ============================================================================

class GhostMemoryDB:
    """
    SQLite-based persistent memory for more complex operations.
    Stores conversations, operations, and learned context.
    """
    
    def __init__(self, db_path: str = "ghost_memory.db"):
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path, check_same_thread=False)
        self.lock = threading.Lock()
        self._init_db()
    
    def _init_db(self):
        cursor = self.conn.cursor()
        
        # Conversations table
        cursor.execute('''CREATE TABLE IF NOT EXISTS conversations (
            entry_id TEXT PRIMARY KEY,
            role TEXT,
            content TEXT,
            timestamp TEXT,
            ghost_tag TEXT,
            context TEXT,
            metadata TEXT
        )''')
        
        # Operations log table
        cursor.execute('''CREATE TABLE IF NOT EXISTS operations (
            operation_id TEXT PRIMARY KEY,
            operation_type TEXT,
            target TEXT,
            parameters TEXT,
            result TEXT,
            success INTEGER,
            duration_ms INTEGER,
            ghost_tag TEXT,
            timestamp TEXT
        )''')
        
        # Context cache table
        cursor.execute('''CREATE TABLE IF NOT EXISTS context_cache (
            key TEXT PRIMARY KEY,
            value TEXT,
            expires_at TEXT,
            ghost_tag TEXT
        )''')
        
        # Learned patterns table
        cursor.execute('''CREATE TABLE IF NOT EXISTS learned_context (
            pattern_id TEXT PRIMARY KEY,
            pattern TEXT,
            response TEXT,
            confidence REAL,
            uses INTEGER,
            ghost_tag TEXT,
            learned_at TEXT
        )''')
        
        self.conn.commit()
    
    def save_message(self, role: str, content: str, ghost_tag: str = "Gx01",
                     context: str = "", metadata: Dict = None):
        """Save a conversation message"""
        entry_id = hashlib.md5(f"{role}:{content}:{datetime.now().isoformat()}".encode()).hexdigest()[:16]
        
        with self.lock:
            cursor = self.conn.cursor()
            cursor.execute('''INSERT INTO conversations VALUES (?,?,?,?,?,?,?)''',
                (entry_id, role, content, datetime.now().isoformat(),
                 ghost_tag, context, json.dumps(metadata or {})))
            self.conn.commit()
        
        return entry_id
    
    def log_operation(self, operation: OperationLog):
        """Log an operation execution"""
        with self.lock:
            cursor = self.conn.cursor()
            cursor.execute('''INSERT INTO operations VALUES (?,?,?,?,?,?,?,?,?)''',
                (operation.operation_id, operation.operation_type, operation.target,
                 json.dumps(operation.parameters), operation.result,
                 1 if operation.success else 0, operation.duration_ms,
                 operation.ghost_tag, operation.timestamp))
            self.conn.commit()
    
    def get_conversation_history(self, ghost_tag: str = None, limit: int = 50) -> List[Dict]:
        """Get conversation history"""
        cursor = self.conn.cursor()
        
        if ghost_tag:
            cursor.execute('''SELECT * FROM conversations 
                WHERE ghost_tag = ? ORDER BY timestamp DESC LIMIT ?''',
                (ghost_tag, limit))
        else:
            cursor.execute('''SELECT * FROM conversations 
                ORDER BY timestamp DESC LIMIT ?''', (limit,))
        
        columns = ['entry_id', 'role', 'content', 'timestamp', 'ghost_tag', 'context', 'metadata']
        return [dict(zip(columns, row)) for row in cursor.fetchall()]
    
    def get_operations(self, ghost_tag: str = None, operation_type: str = None,
                       limit: int = 50) -> List[Dict]:
        """Get operation logs"""
        cursor = self.conn.cursor()
        query = 'SELECT * FROM operations WHERE 1=1'
        params = []
        
        if ghost_tag:
            query += ' AND ghost_tag = ?'
            params.append(ghost_tag)
        if operation_type:
            query += ' AND operation_type = ?'
            params.append(operation_type)
        
        query += ' ORDER BY timestamp DESC LIMIT ?'
        params.append(limit)
        
        cursor.execute(query, params)
        
        columns = ['operation_id', 'operation_type', 'target', 'parameters',
                   'result', 'success', 'duration_ms', 'ghost_tag', 'timestamp']
        return [dict(zip(columns, row)) for row in cursor.fetchall()]
    
    def cache_context(self, key: str, value: Any, ghost_tag: str = "Gx01",
                      ttl_seconds: int = 3600):
        """Cache a context value"""
        from datetime import timedelta
        expires = datetime.now() + timedelta(seconds=ttl_seconds)
        
        with self.lock:
            cursor = self.conn.cursor()
            cursor.execute('''INSERT OR REPLACE INTO context_cache VALUES (?,?,?,?)''',
                (key, json.dumps(value), expires.isoformat(), ghost_tag))
            self.conn.commit()
    
    def get_cached_context(self, key: str) -> Optional[Any]:
        """Get a cached context value"""
        cursor = self.conn.cursor()
        cursor.execute('SELECT value, expires_at FROM context_cache WHERE key = ?', (key,))
        row = cursor.fetchone()
        
        if row:
            value, expires_at = row
            if datetime.fromisoformat(expires_at) > datetime.now():
                return json.loads(value)
            else:
                # Expired - remove it
                cursor.execute('DELETE FROM context_cache WHERE key = ?', (key,))
                self.conn.commit()
        
        return None
    
    def learn_pattern(self, pattern: str, response: str, ghost_tag: str = "Gx01",
                      confidence: float = 0.5):
        """Learn a pattern-response pair"""
        pattern_id = hashlib.md5(pattern.encode()).hexdigest()[:16]
        
        with self.lock:
            cursor = self.conn.cursor()
            
            # Check if pattern exists
            cursor.execute('SELECT uses, confidence FROM learned_context WHERE pattern_id = ?',
                          (pattern_id,))
            existing = cursor.fetchone()
            
            if existing:
                uses, old_conf = existing
                new_conf = (old_conf * uses + confidence) / (uses + 1)
                cursor.execute('''UPDATE learned_context 
                    SET response = ?, confidence = ?, uses = ?, learned_at = ?
                    WHERE pattern_id = ?''',
                    (response, new_conf, uses + 1, datetime.now().isoformat(), pattern_id))
            else:
                cursor.execute('''INSERT INTO learned_context VALUES (?,?,?,?,?,?,?)''',
                    (pattern_id, pattern, response, confidence, 1,
                     ghost_tag, datetime.now().isoformat()))
            
            self.conn.commit()
    
    def find_learned_response(self, input_text: str, threshold: float = 0.3) -> Optional[Dict]:
        """Find a learned response for input"""
        cursor = self.conn.cursor()
        cursor.execute('''SELECT pattern, response, confidence, uses 
            FROM learned_context WHERE confidence >= ? ORDER BY uses DESC''',
            (threshold,))
        
        input_lower = input_text.lower()
        
        for row in cursor.fetchall():
            pattern, response, confidence, uses = row
            if pattern.lower() in input_lower or input_lower in pattern.lower():
                return {
                    'pattern': pattern,
                    'response': response,
                    'confidence': confidence,
                    'uses': uses
                }
        
        return None
    
    def get_stats(self) -> Dict:
        """Get memory statistics"""
        cursor = self.conn.cursor()
        
        stats = {}
        
        cursor.execute('SELECT COUNT(*) FROM conversations')
        stats['total_messages'] = cursor.fetchone()[0]
        
        cursor.execute('SELECT COUNT(*) FROM operations')
        stats['total_operations'] = cursor.fetchone()[0]
        
        cursor.execute('SELECT COUNT(*) FROM learned_context')
        stats['learned_patterns'] = cursor.fetchone()[0]
        
        cursor.execute('SELECT COUNT(*) FROM context_cache')
        stats['cached_contexts'] = cursor.fetchone()[0]
        
        cursor.execute('SELECT COUNT(DISTINCT ghost_tag) FROM conversations')
        stats['unique_sessions'] = cursor.fetchone()[0]
        
        return stats
    
    def clear_session(self, ghost_tag: str):
        """Clear all data for a session"""
        with self.lock:
            cursor = self.conn.cursor()
            cursor.execute('DELETE FROM conversations WHERE ghost_tag = ?', (ghost_tag,))
            cursor.execute('DELETE FROM operations WHERE ghost_tag = ?', (ghost_tag,))
            cursor.execute('DELETE FROM context_cache WHERE ghost_tag = ?', (ghost_tag,))
            self.conn.commit()
    
    def export_session(self, ghost_tag: str, filepath: str) -> bool:
        """Export a session to JSON"""
        try:
            data = {
                'ghost_tag': ghost_tag,
                'exported_at': datetime.now().isoformat(),
                'conversations': self.get_conversation_history(ghost_tag, limit=1000),
                'operations': self.get_operations(ghost_tag, limit=1000),
                'stats': self.get_stats()
            }
            
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2)
            
            return True
        except Exception as e:
            return False


# ============================================================================
# HYBRID MEMORY - COMBINES FILE AND DB
# ============================================================================

class HybridGhostMemory:
    """
    Hybrid memory combining fast file-based logging with SQLite persistence.
    Best of both worlds for GhostWhisper operations.
    """
    
    def __init__(self, log_dir: str = "operations", db_path: str = "ghost_memory.db"):
        self.file_memory = GhostMemory(os.path.join(log_dir, "ai_session.log"))
        self.db_memory = GhostMemoryDB(db_path)
        self.ghost_tag = None
    
    def set_session(self, ghost_tag: str):
        """Set current session tag"""
        self.ghost_tag = ghost_tag
    
    def save(self, role: str, message: str):
        """Save message to both file and DB"""
        # File-based (fast, compatible)
        self.file_memory.save(role, message)
        
        # DB-based (persistent, searchable)
        self.db_memory.save_message(role, message, self.ghost_tag or "Gx01")
    
    def save_interaction(self, user_input: str, ai_response: str):
        """Save complete interaction"""
        self.file_memory.save_interaction(user_input, ai_response)
        self.db_memory.save_message("user", user_input, self.ghost_tag or "Gx01")
        self.db_memory.save_message("ghost", ai_response, self.ghost_tag or "Gx01")
    
    def load_recent_history(self, limit: int = 10) -> List[str]:
        """Load recent history from file (faster)"""
        return self.file_memory.load_recent_history(limit)
    
    def search(self, query: str, limit: int = 10) -> List[Dict]:
        """Search using file-based memory"""
        return self.file_memory.search(query, limit)
    
    def log_operation(self, operation_type: str, target: str, parameters: Dict,
                      result: str, success: bool, duration_ms: int):
        """Log an operation"""
        op = OperationLog(
            operation_id=hashlib.md5(f"{operation_type}:{target}:{datetime.now().isoformat()}".encode()).hexdigest()[:16],
            operation_type=operation_type,
            target=target,
            parameters=parameters,
            result=result,
            success=success,
            duration_ms=duration_ms,
            ghost_tag=self.ghost_tag or "Gx01",
            timestamp=datetime.now().isoformat()
        )
        self.db_memory.log_operation(op)
    
    def get_stats(self) -> Dict:
        """Get combined statistics"""
        return self.db_memory.get_stats()
    
    def learn(self, pattern: str, response: str, confidence: float = 0.5):
        """Learn a pattern"""
        self.db_memory.learn_pattern(pattern, response, self.ghost_tag or "Gx01", confidence)
    
    def find_response(self, input_text: str) -> Optional[Dict]:
        """Find a learned response"""
        return self.db_memory.find_learned_response(input_text)
    
    def export(self, filepath: str) -> bool:
        """Export session data"""
        return self.db_memory.export_session(self.ghost_tag or "Gx01", filepath)
    
    def clear(self, session_only: bool = True):
        """Clear memory"""
        if session_only and self.ghost_tag:
            self.db_memory.clear_session(self.ghost_tag)
        else:
            self.file_memory.clear()


# Export for module use
__all__ = ['GhostMemory', 'GhostMemoryDB', 'HybridGhostMemory', 'MemoryEntry', 'OperationLog']
