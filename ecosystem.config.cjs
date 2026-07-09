module.exports = {
  apps: [
    {
      name: 'arkinterview',
      script: 'backend/server.mjs',
      cwd: '/opt/arkinterview',
      env: {
        NODE_ENV: 'production',
        HOST: '0.0.0.0',
        PORT: '8787'
      }
    }
  ]
};
