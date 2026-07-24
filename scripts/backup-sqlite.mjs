import Database from 'better-sqlite3';
import { existsSync } from 'node:fs';
import { mkdir } from 'node:fs/promises';
import path from 'node:path';

const sourceFile = process.argv[2] ? path.resolve(process.argv[2]) : '';
const destinationFile = process.argv[3] ? path.resolve(process.argv[3]) : '';

if (!sourceFile || !destinationFile) {
  throw new Error('Usage: node scripts/backup-sqlite.mjs <source.sqlite> <destination.sqlite>');
}
if (!existsSync(sourceFile)) {
  throw new Error(`SQLite source file does not exist: ${sourceFile}`);
}
if (sourceFile === destinationFile) {
  throw new Error('SQLite backup destination must differ from the source file');
}

await mkdir(path.dirname(destinationFile), { recursive: true });

const source = new Database(sourceFile, {
  readonly: true,
  fileMustExist: true
});

try {
  await source.backup(destinationFile);
} finally {
  source.close();
}

const backup = new Database(destinationFile, {
  readonly: true,
  fileMustExist: true
});

try {
  const integrity = backup.pragma('integrity_check', { simple: true });
  if (integrity !== 'ok') {
    throw new Error(`SQLite backup integrity check failed: ${integrity}`);
  }
} finally {
  backup.close();
}

console.log(`SQLite backup created: ${destinationFile}`);
