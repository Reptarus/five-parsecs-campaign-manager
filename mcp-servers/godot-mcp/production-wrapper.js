#!/usr/bin/env node

/**
 * Production wrapper for Godot MCP Server
 * Ensures clean stdout for MCP protocol compliance
 */

import { spawn } from 'child_process';
import path from 'path';

// Suppress all console output in production
const originalConsoleLog = console.log;
const originalConsoleDebug = console.debug;
const originalConsoleError = console.error;

// Redirect console methods to stderr in production
if (process.env.NODE_ENV === 'production' || process.env.DEBUG === 'false') {
    console.log = (...args) => {
        // Only allow JSON-RPC messages to stdout
        const message = args[0];
        if (typeof message === 'string' && 
            (message.includes('"jsonrpc"') || message.includes('Content-Length'))) {
            originalConsoleLog.apply(console, args);
        } else {
            // Send everything else to stderr
            console.error(...args);
        }
    };
    
    console.debug = (...args) => {
        // Never output debug to stdout
        if (process.env.DEBUG === 'true') {
            console.error('[DEBUG]', ...args);
        }
    };
}

// Load and start the actual server
import('./build/index.js');
