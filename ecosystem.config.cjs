module.exports = {
  apps: [
    {
      name: 'arkinterview',
      script: 'backend/server.mjs',
      cwd: '/opt/arkinterview',
      env: {
        NODE_ENV: 'production',
        HOST: '0.0.0.0',
        PORT: '8787',
        DB_FILE: process.env.DB_FILE || '/opt/arkinterview/backend/storage/arkinterview.sqlite',
        LEGACY_DB_FILE: process.env.LEGACY_DB_FILE || '/opt/arkinterview/backend/storage/db.json',
        ADMIN_TOKEN: process.env.ADMIN_TOKEN || ''
      }
    }
  ]
};
