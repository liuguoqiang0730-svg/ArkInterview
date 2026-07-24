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
        ADMIN_TOKEN: process.env.ADMIN_TOKEN || '',
        HUAWEI_CLIENT_ID: process.env.HUAWEI_CLIENT_ID || '',
        HUAWEI_CLIENT_SECRET: process.env.HUAWEI_CLIENT_SECRET || '',
        HUAWEI_REDIRECT_URI: process.env.HUAWEI_REDIRECT_URI || '',
        AUTH_ACCESS_TTL_SECONDS: process.env.AUTH_ACCESS_TTL_SECONDS || '900',
        AUTH_REFRESH_TTL_SECONDS: process.env.AUTH_REFRESH_TTL_SECONDS || '2592000'
      }
    }
  ]
};
