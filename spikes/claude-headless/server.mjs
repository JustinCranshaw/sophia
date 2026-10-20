// Minimal stdio MCP server exposing Sophia's two notebook tools.
// propose_page records a pending proposal and never writes a page.
// Usage: node server.mjs <notebook-dir>
import { appendFileSync, readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { createInterface } from 'node:readline';

const dir = process.argv[2];
const log = (entry) => appendFileSync(join(dir, 'server-log.jsonl'), JSON.stringify({ at: new Date().toISOString(), ...entry }) + '\n');
const send = (msg) => process.stdout.write(JSON.stringify(msg) + '\n');

const TOOLS = [
  {
    name: 'read_page',
    description: 'Read an accepted page from the current notebook by file name.',
    inputSchema: { type: 'object', properties: { file: { type: 'string' } }, required: ['file'] }
  },
  {
    name: 'propose_page',
    description: 'Propose a new page for the notebook. This creates a pending proposal only; nothing is saved until the person accepts it in the app.',
    inputSchema: {
      type: 'object',
      properties: {
        title: { type: 'string' },
        content: { type: 'string', description: 'Markdown body of the page' }
      },
      required: ['title', 'content']
    }
  }
];

let proposals = 0;

function call(name, args) {
  if (name === 'propose_page') {
    proposals += 1;
    const id = 'pr-' + proposals;
    appendFileSync(join(dir, 'proposals.jsonl'), JSON.stringify({ proposal: id, title: args.title, content: args.content }) + '\n');
    log({ tool: name, proposal: id, title: args.title });
    return `Proposal ${id} recorded. It is pending: the person has not accepted it, and nothing has been saved.`;
  }
  if (name === 'read_page') {
    const path = join(dir, 'pages', String(args.file).replace(/[\/\\]/g, ''));
    log({ tool: name, file: args.file });
    return existsSync(path) ? readFileSync(path, 'utf8') : `No accepted page named ${args.file}.`;
  }
  throw new Error('Unknown tool ' + name);
}

createInterface({ input: process.stdin }).on('line', (line) => {
  if (!line.trim()) return;
  const msg = JSON.parse(line);
  log({ method: msg.method });
  if (msg.method === 'initialize') {
    send({ jsonrpc: '2.0', id: msg.id, result: {
      protocolVersion: msg.params.protocolVersion,
      capabilities: { tools: {} },
      serverInfo: { name: 'sophia', version: '0.0.1' }
    } });
  } else if (msg.method === 'tools/list') {
    send({ jsonrpc: '2.0', id: msg.id, result: { tools: TOOLS } });
  } else if (msg.method === 'tools/call') {
    try {
      send({ jsonrpc: '2.0', id: msg.id, result: { content: [{ type: 'text', text: call(msg.params.name, msg.params.arguments || {}) }] } });
    } catch (e) {
      send({ jsonrpc: '2.0', id: msg.id, result: { content: [{ type: 'text', text: e.message }], isError: true } });
    }
  } else if (msg.id !== undefined) {
    send({ jsonrpc: '2.0', id: msg.id, result: {} });
  }
});
