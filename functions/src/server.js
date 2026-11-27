"use strict";
const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {createServer} = require("./http_app");

function configuration(env) {
  const mode = env.PHARMALAB_ENV;
  const projectId = env.FIREBASE_PROJECT_ID;
  if (!["production", "test", "emulator"].includes(mode)) throw new Error("Configura PHARMALAB_ENV explícitamente.");
  const production = mode === "production";
  if (production) {
    if (env.NODE_ENV !== "production" || projectId !== "proyecto-pharmalab" ||
        !env.GOOGLE_APPLICATION_CREDENTIALS || env.FIRESTORE_EMULATOR_HOST ||
        env.FIREBASE_AUTH_EMULATOR_HOST || env.FUNCTIONS_EMULATOR) throw new Error("Configuración de producción incompatible.");
  } else if (projectId !== "demo-pharmalab" ||
      !/^(127\.0\.0\.1|localhost):8080$/.test(env.FIRESTORE_EMULATOR_HOST || "") ||
      !/^(127\.0\.0\.1|localhost):9099$/.test(env.FIREBASE_AUTH_EMULATOR_HOST || "") ||
      env.GOOGLE_APPLICATION_CREDENTIALS) throw new Error("Las pruebas requieren ambos emuladores demo y ninguna credencial real.");
  const port = Number(env.PORT || 3000), limit = Number(env.RATE_LIMIT_PER_MINUTE || 60);
  if (!Number.isInteger(port) || port < 1 || port > 65535 || !Number.isInteger(limit) || limit < 1 || limit > 600) throw new Error("Puerto o límite inválido.");
  return {projectId, production, port, limit, origins: (env.CORS_ORIGINS || "").split(",").map((v) => v.trim()).filter(Boolean)};
}
function start(env = process.env) {
  const config = configuration(env);
  const smoke = process.argv.includes("--smoke-test");
  if (smoke && config.production) throw new Error("Smoke local requiere emuladores.");
  if (config.production) {
    // Verificar correspondencia sin imprimir ni modificar el archivo secreto.
    const credentials = JSON.parse(require("node:fs").readFileSync(env.GOOGLE_APPLICATION_CREDENTIALS, "utf8"));
    if (credentials.type !== "service_account" || credentials.project_id !== config.projectId ||
        typeof credentials.client_email !== "string" || typeof credentials.private_key !== "string") {
      throw new Error("Cuenta de servicio incompatible.");
    }
  }
  const app = initializeApp({projectId: config.projectId, ...(config.production ? {credential: applicationDefault()} : {})});
  const server = createServer({...config, db: getFirestore(app), auth: getAuth(app)});
  server.listen(config.port, "0.0.0.0", () => console.log(JSON.stringify({event: "server_started", port: config.port, mode: env.PHARMALAB_ENV, node: process.version})));
  if (smoke) server.once("listening", async () => {
    try {
      const response = await fetch(`http://127.0.0.1:${config.port}/health`);
      if (response.status !== 200 || (await response.json()).status !== "ok") throw new Error("Health falló.");
      console.log("npm start smoke: /health OK (solo emuladores)");
      server.close();
    } catch { server.close(); process.exitCode = 1; }
  });
  for (const signal of ["SIGTERM", "SIGINT"]) process.once(signal, () => {
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10000).unref();
  });
  return server;
}
if (require.main === module) {
  try { start(); } catch { console.error("Inicio rechazado: revisa las variables de entorno y las credenciales del servidor."); process.exitCode = 1; }
}
module.exports = {configuration, start};
