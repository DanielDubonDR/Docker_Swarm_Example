#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
#  SwarmShop — Script de setup completo
#  Uso: chmod +x setup.sh && ./setup.sh
# ══════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Colores ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

banner() { echo -e "\n${CYAN}${BOLD}══ $1 ══${RESET}\n"; }
ok()     { echo -e "${GREEN}✅  $1${RESET}"; }
info()   { echo -e "${YELLOW}➜  $1${RESET}"; }
err()    { echo -e "${RED}❌  $1${RESET}"; exit 1; }
step()   { echo -e "\n${BOLD}PASO $1 — $2${RESET}"; }

# ── Verificar Docker ───────────────────────────────────────────────────
banner "SwarmShop — Docker Swarm Demo Setup"

command -v docker >/dev/null 2>&1 || err "Docker no está instalado"
ok "Docker encontrado: $(docker --version | head -1)"

# ── PASO 1: Construir imágenes ─────────────────────────────────────────
step 1 "Construir imágenes Docker"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info "Construyendo imagen API..."
docker build -t swarm-demo-api:latest "$SCRIPT_DIR/api" --quiet && ok "swarm-demo-api:latest ✓"

info "Construyendo imagen Web..."
docker build -t swarm-demo-web:latest "$SCRIPT_DIR/web" --quiet && ok "swarm-demo-web:latest ✓"

info "Construyendo imagen NGINX..."
docker build -t swarm-demo-nginx:latest "$SCRIPT_DIR/nginx" --quiet && ok "swarm-demo-nginx:latest ✓"

# ── PASO 2: Inicializar Swarm ──────────────────────────────────────────
step 2 "Inicializar Docker Swarm"

if docker info 2>/dev/null | grep -q "Swarm: active"; then
    ok "Swarm ya está activo"
else
    info "Inicializando Swarm..."
    docker swarm init --advertise-addr 127.0.0.1 2>/dev/null || \
    docker swarm init --advertise-addr $(hostname -I | awk '{print $1}') || true
    ok "Swarm inicializado"
fi

docker node ls
echo ""

# ── PASO 3: Desplegar el stack ─────────────────────────────────────────
step 3 "Desplegar stack en Swarm"

info "Eliminando stack anterior si existe..."
docker stack rm swarm 2>/dev/null && sleep 5 || true

info "Desplegando stack 'swarm'..."
docker stack deploy -c "$SCRIPT_DIR/docker-stack.yml" swarm

# ── PASO 4: Esperar que los servicios estén listos ─────────────────────
step 4 "Esperando que los servicios arranquen"

info "Esperando 15 segundos para que los contenedores levanten..."
for i in $(seq 1 15); do
    printf "."
    sleep 1
done
echo ""

# ── PASO 5: Verificar estado ───────────────────────────────────────────
step 5 "Verificar estado del stack"

echo ""
docker stack services swarm
echo ""
docker stack ps swarm --no-trunc 2>/dev/null | head -20

# ── PASO 6: Test de conectividad ───────────────────────────────────────
step 6 "Prueba de conectividad"

MAX_RETRIES=15
for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf http://localhost:80/api/health > /dev/null 2>&1; then
        ok "API respondiendo en http://localhost:80/api/health"
        break
    fi
    info "Intento $i/$MAX_RETRIES — esperando..."
    sleep 3
done

echo ""
banner "¡Stack desplegado exitosamente!"
echo -e "  ${BOLD}🌐 Frontend:${RESET}  http://localhost:80"
echo -e "  ${BOLD}📡 API:${RESET}       http://localhost:80/api/health"
echo -e "  ${BOLD}📦 Productos:${RESET} http://localhost:80/api/products"
echo ""
echo -e "  ${CYAN}Comandos útiles:${RESET}"
echo -e "  docker stack services swarm          # Ver servicios"
echo -e "  docker service scale swarm_api=6     # Escalar API a 6 réplicas"
echo -e "  docker service logs swarm_api -f     # Ver logs del API"
echo -e "  docker stack rm swarm                # Eliminar todo"
echo ""
