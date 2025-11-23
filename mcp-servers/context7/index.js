/**
 * Context7 MCP Server for Godot Development
 * Maintains persistent context across development sessions
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { Redis } from '@upstash/redis';
import * as fs from 'fs/promises';
import * as path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

// Load environment configuration
dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = path.resolve(__dirname, '../../');

// Initialize Redis client for context storage
const redis = process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN
  ? new Redis({
      url: process.env.UPSTASH_REDIS_REST_URL,
      token: process.env.UPSTASH_REDIS_REST_TOKEN,
    })
  : null;

// Fallback to local storage if Redis not configured
const LOCAL_CONTEXT_DIR = path.join(PROJECT_ROOT, '.context7');

/**
 * Context Manager for Godot Development
 */
class GodotContextManager {
  constructor() {
    this.namespace = 'godot-five-parsecs';
  }

  async saveContext(key, value, ttl = 86400) {
    const fullKey = `${this.namespace}:${key}`;
    
    if (redis) {
      // Save to Upstash Redis
      await redis.set(fullKey, JSON.stringify(value), { ex: ttl });
    } else {
      // Fallback to local storage
      await this.saveLocal(fullKey, value);
    }
    
    return { success: true, key: fullKey };
  }

  async loadContext(key) {
    const fullKey = `${this.namespace}:${key}`;
    
    if (redis) {
      const value = await redis.get(fullKey);
      return value ? JSON.parse(value) : null;
    } else {
      return await this.loadLocal(fullKey);
    }
  }

  async listContexts(pattern = '*') {
    const searchPattern = `${this.namespace}:${pattern}`;
    
    if (redis) {
      const keys = await redis.keys(searchPattern);
      return keys.map(k => k.replace(`${this.namespace}:`, ''));
    } else {
      return await this.listLocal(pattern);
    }
  }

  async deleteContext(key) {
    const fullKey = `${this.namespace}:${key}`;
    
    if (redis) {
      await redis.del(fullKey);
    } else {
      await this.deleteLocal(fullKey);
    }
    
    return { success: true, key: fullKey };
  }

  // Local storage methods
  async saveLocal(key, value) {
    await fs.mkdir(LOCAL_CONTEXT_DIR, { recursive: true });
    const filepath = path.join(LOCAL_CONTEXT_DIR, `${key}.json`);
    await fs.writeFile(filepath, JSON.stringify(value, null, 2));
  }

  async loadLocal(key) {
    try {
      const filepath = path.join(LOCAL_CONTEXT_DIR, `${key}.json`);
      const content = await fs.readFile(filepath, 'utf-8');
      return JSON.parse(content);
    } catch {
      return null;
    }
  }

  async listLocal(pattern) {
    try {
      await fs.mkdir(LOCAL_CONTEXT_DIR, { recursive: true });
      const files = await fs.readdir(LOCAL_CONTEXT_DIR);
      return files
        .filter(f => f.endsWith('.json'))
        .map(f => f.replace('.json', '').replace(`${this.namespace}:`, ''));
    } catch {
      return [];
    }
  }

  async deleteLocal(key) {
    try {
      const filepath = path.join(LOCAL_CONTEXT_DIR, `${key}.json`);
      await fs.unlink(filepath);
    } catch {
      // Ignore if file doesn't exist
    }
  }
}

/**
 * MCP Server Implementation
 */
class Context7Server {
  constructor() {
    this.contextManager = new GodotContextManager();
    this.server = new Server(
      {
        name: 'context7',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupHandlers();
  }

  setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'save-context',
          description: 'Save development context for Godot project',
          inputSchema: {
            type: 'object',
            properties: {
              key: {
                type: 'string',
                description: 'Context key (e.g., session:current, architecture:v1)',
              },
              value: {
                type: 'object',
                description: 'Context data to save',
              },
              ttl: {
                type: 'number',
                description: 'Time to live in seconds (default: 86400)',
              },
            },
            required: ['key', 'value'],
          },
        },
        {
          name: 'load-context',
          description: 'Load saved development context',
          inputSchema: {
            type: 'object',
            properties: {
              key: {
                type: 'string',
                description: 'Context key to load',
              },
            },
            required: ['key'],
          },
        },
        {
          name: 'list-contexts',
          description: 'List available contexts',
          inputSchema: {
            type: 'object',
            properties: {
              pattern: {
                type: 'string',
                description: 'Filter pattern (default: *)',
              },
            },
          },
        },
        {
          name: 'delete-context',
          description: 'Delete a saved context',
          inputSchema: {
            type: 'object',
            properties: {
              key: {
                type: 'string',
                description: 'Context key to delete',
              },
            },
            required: ['key'],
          },
        },
        {
          name: 'save-session',
          description: 'Save current development session state',
          inputSchema: {
            type: 'object',
            properties: {
              sessionId: {
                type: 'string',
                description: 'Session identifier',
              },
              files: {
                type: 'array',
                items: { type: 'string' },
                description: 'List of files being worked on',
              },
              context: {
                type: 'object',
                description: 'Additional session context',
              },
            },
            required: ['sessionId'],
          },
        },
        {
          name: 'restore-session',
          description: 'Restore a previous development session',
          inputSchema: {
            type: 'object',
            properties: {
              sessionId: {
                type: 'string',
                description: 'Session identifier to restore',
              },
            },
            required: ['sessionId'],
          },
        },
        {
          name: 'save-test-results',
          description: 'Save Godot test results for analysis',
          inputSchema: {
            type: 'object',
            properties: {
              testId: {
                type: 'string',
                description: 'Test run identifier',
              },
              results: {
                type: 'object',
                description: 'Test results data',
              },
            },
            required: ['testId', 'results'],
          },
        },
        {
          name: 'get-library-docs',
          description: 'Get Godot library documentation context',
          inputSchema: {
            type: 'object',
            properties: {
              library: {
                type: 'string',
                description: 'Library name (e.g., gdscript, godot4)',
              },
            },
            required: ['library'],
          },
        },
        {
          name: 'resolve-library-id',
          description: 'Resolve library ID for context management',
          inputSchema: {
            type: 'object',
            properties: {
              name: {
                type: 'string',
                description: 'Library name to resolve',
              },
            },
            required: ['name'],
          },
        },
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;
      
      try {
        switch (name) {
          case 'save-context':
            return await this.handleSaveContext(args);
          case 'load-context':
            return await this.handleLoadContext(args);
          case 'list-contexts':
            return await this.handleListContexts(args);
          case 'delete-context':
            return await this.handleDeleteContext(args);
          case 'save-session':
            return await this.handleSaveSession(args);
          case 'restore-session':
            return await this.handleRestoreSession(args);
          case 'save-test-results':
            return await this.handleSaveTestResults(args);
          case 'get-library-docs':
            return await this.handleGetLibraryDocs(args);
          case 'resolve-library-id':
            return await this.handleResolveLibraryId(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: 'text',
              text: `Error: ${error.message}`,
            },
          ],
        };
      }
    });
  }

  async handleSaveContext(args) {
    const result = await this.contextManager.saveContext(
      args.key,
      args.value,
      args.ttl
    );
    
    return {
      content: [
        {
          type: 'text',
          text: `✅ Context saved: ${args.key}`,
        },
      ],
    };
  }

  async handleLoadContext(args) {
    const context = await this.contextManager.loadContext(args.key);
    
    if (!context) {
      return {
        content: [
          {
            type: 'text',
            text: `❌ Context not found: ${args.key}`,
          },
        ],
      };
    }
    
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(context, null, 2),
        },
      ],
    };
  }

  async handleListContexts(args) {
    const contexts = await this.contextManager.listContexts(args.pattern || '*');
    
    return {
      content: [
        {
          type: 'text',
          text: contexts.length > 0 
            ? `📋 Available contexts:\n${contexts.join('\n')}`
            : '📋 No contexts found',
        },
      ],
    };
  }

  async handleDeleteContext(args) {
    await this.contextManager.deleteContext(args.key);
    
    return {
      content: [
        {
          type: 'text',
          text: `🗑️ Context deleted: ${args.key}`,
        },
      ],
    };
  }

  async handleSaveSession(args) {
    const sessionData = {
      id: args.sessionId,
      timestamp: Date.now(),
      files: args.files || [],
      context: args.context || {},
    };
    
    await this.contextManager.saveContext(
      `session:${args.sessionId}`,
      sessionData
    );
    
    return {
      content: [
        {
          type: 'text',
          text: `✅ Session saved: ${args.sessionId}`,
        },
      ],
    };
  }

  async handleRestoreSession(args) {
    const session = await this.contextManager.loadContext(
      `session:${args.sessionId}`
    );
    
    if (!session) {
      return {
        content: [
          {
            type: 'text',
            text: `❌ Session not found: ${args.sessionId}`,
          },
        ],
      };
    }
    
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(session, null, 2),
        },
      ],
    };
  }

  async handleSaveTestResults(args) {
    const testData = {
      id: args.testId,
      timestamp: Date.now(),
      results: args.results,
    };
    
    await this.contextManager.saveContext(
      `test:${args.testId}`,
      testData
    );
    
    return {
      content: [
        {
          type: 'text',
          text: `✅ Test results saved: ${args.testId}`,
        },
      ],
    };
  }

  async handleGetLibraryDocs(args) {
    // This would normally fetch from a documentation source
    const docContext = {
      library: args.library,
      version: '4.4.1',
      timestamp: Date.now(),
      documentation: `Documentation context for ${args.library}`,
    };
    
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(docContext, null, 2),
        },
      ],
    };
  }

  async handleResolveLibraryId(args) {
    // Map library names to IDs
    const libraryMap = {
      'godot': 'godot-4.4.1',
      'gdscript': 'gdscript-2.0',
      'five-parsecs': 'five-parsecs-campaign-manager',
    };
    
    const libraryId = libraryMap[args.name] || args.name;
    
    return {
      content: [
        {
          type: 'text',
          text: `Library ID: ${libraryId}`,
        },
      ],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('Context7 MCP Server started successfully');
  }
}

// Start the server
const server = new Context7Server();
server.run().catch(console.error);
