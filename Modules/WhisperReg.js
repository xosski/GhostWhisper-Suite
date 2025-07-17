// WhisperReg: A GhostWhisper Suite Component
// Simulated Registry Handler for Red Team Research

const fs = require('fs');
const path = require('path');
const os = require('os');

const REG_PATH = path.join(os.tmpdir(), 'whisperreg.log');

const WhisperReg = {
    keychain: {},

    init() {
        this.log('WhisperReg initialized.');
        this.createMockPersistence();
    },

    log(entry) {
        const timestamp = new Date().toISOString();
        const formatted = `[${timestamp}] ${entry}\n`;
        fs.appendFileSync(REG_PATH, formatted);
    },

    registerKey(hive, key, value) {
        if (!this.keychain[hive]) this.keychain[hive] = {};
        this.keychain[hive][key] = value;
        this.log(`Registered ${hive}\\${key} = ${value}`);
    },

    createMockPersistence() {
        this.registerKey('HKCU', 'Software\\GhostWhisper\\Run', 'C:\\Users\\Public\\ghostwhisper.exe');
        this.registerKey('HKLM', 'System\\Startup\\GhostAgent', 'ghost.exe /silent');
    },

    export() {
        this.log('Exporting keychain.');
        return JSON.stringify(this.keychain, null, 2);
    },

    simulateDetection() {
        this.log('Simulated AV detection triggered. Bypassed.');
        return {
            status: 'bypassed',
            signature: 'WhisperReg/stealth-reg-01',
            timestamp: new Date().toISOString()
        };
    }
};

// Initialize and export
WhisperReg.init();
module.exports = WhisperReg;
