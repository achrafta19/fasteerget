// PM2 process file for a bare-metal VPS (no Docker).
//   pm2 start ecosystem.config.cjs && pm2 save && pm2 startup
module.exports = {
  apps: [
    {
      name: "vanguard-app",
      cwd: __dirname,
      script: "node_modules/next/dist/bin/next",
      args: "start -p 3000",
      instances: 1,            // keep 1: in-process engine state must not fork
      exec_mode: "fork",
      autorestart: true,
      max_memory_restart: "768M",
      env: {
        NODE_ENV: "production",
        PORT: 3000,
      },
      out_file: "./logs/app.out.log",
      error_file: "./logs/app.err.log",
      time: true,
    },
  ],
};
