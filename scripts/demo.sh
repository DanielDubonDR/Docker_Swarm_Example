#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
#  SwarmShop — Comandos de demostración interactiva
#  Ejecuta cada función por separado para la demo
# ══════════════════════════════════════════════════════════════════════

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo -e "${BOLD} $1${RESET}"; echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"; }

# ── DEMO 1: Ver el balanceo de carga en acción ──────────────────────────
demo_balanceo() {
    header "DEMO 1 — Balanceo de carga visible"
    echo "Haciendo 10 requests al API y mostrando qué contenedor responde..."
    echo ""
    for i in $(seq 1 10); do
        RESPONSE=$(curl -sf http://localhost:80/api/health 2>/dev/null || echo '{"container_id":"ERROR"}')
        CONTAINER=$(echo $RESPONSE | grep -o '"container_id":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "error")
        HOSTNAME=$(echo $RESPONSE | grep -o '"hostname":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "error")
        echo -e "  Request ${BOLD}$i${RESET} → ${GREEN}container: $CONTAINER${RESET} (hostname: $HOSTNAME)"
        sleep 0.3
    done
    echo ""
    echo -e "${YELLOW}⚠️  Observa cómo los requests van a diferentes contenedores${RESET}"
}

# ── DEMO 2: Escalar el servicio ─────────────────────────────────────────
demo_escalar() {
    header "DEMO 2 — Escalar el API a 6 réplicas"
    echo "Estado actual:"
    docker service ls --filter name=swarm_api
    echo ""
    echo "Escalando a 6 réplicas..."
    docker service scale swarm_api=6
    echo ""
    echo "Esperando que levanten..."
    sleep 10
    docker service ps swarm_api --format "table {{.Name}}\t{{.Node}}\t{{.CurrentState}}"
    echo ""
    echo -e "${GREEN}✅ Ahora hay 6 réplicas. Recarga la web para ver más contenedores${RESET}"
}

# ── DEMO 3: Alta disponibilidad — matar un contenedor ───────────────────
demo_alta_disponibilidad() {
    header "DEMO 3 — Alta disponibilidad: matar un contenedor"
    echo "Contenedores API corriendo:"
    docker ps --filter name=swarm_api --format "table {{.ID}}\t{{.Names}}\t{{.Status}}" | head -5
    echo ""

    CONTAINER_ID=$(docker ps --filter name=swarm_api -q | head -1)
    if [ -z "$CONTAINER_ID" ]; then
        echo "No se encontraron contenedores del API"
        return 1
    fi

    echo -e "Matando el contenedor: ${RED}$CONTAINER_ID${RESET}"
    docker kill "$CONTAINER_ID"
    echo ""
    echo "Observando cómo Swarm detecta la caída y relanza..."
    for i in $(seq 1 8); do
        printf "."
        sleep 1
    done
    echo ""
    echo ""
    docker service ps swarm_api --format "table {{.Name}}\t{{.CurrentState}}\t{{.Error}}" | head -10
    echo ""
    echo -e "${GREEN}✅ Swarm relanzó automáticamente el contenedor caído${RESET}"
}

# ── DEMO 4: Rolling Update (actualización sin downtime) ──────────────────
demo_rolling_update() {
    header "DEMO 4 — Rolling Update sin downtime"
    echo "Estado actual del servicio:"
    docker service inspect swarm_api --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}'
    echo ""
    echo "Actualizando imagen con parámetros de rolling update..."
    echo "(update-parallelism=1, update-delay=5s, order=start-first)"
    echo ""
    docker service update \
        --update-parallelism 1 \
        --update-delay 5s \
        --update-order start-first \
        --image swarm-demo-api:latest \
        swarm_api
    echo ""
    echo -e "${GREEN}✅ Actualización completada sin interrumpir el servicio${RESET}"
    echo ""
    echo "Mientras se actualiza, el API sigue respondiendo:"
    curl -s http://localhost:80/api/health | python3 -m json.tool 2>/dev/null || \
    curl -s http://localhost:80/api/health
}

# ── DEMO 5: Ver logs del servicio ───────────────────────────────────────
demo_logs() {
    header "DEMO 5 — Logs del servicio (todas las réplicas)"
    echo "Últimas 20 líneas de logs de TODAS las réplicas del API:"
    echo ""
    docker service logs swarm_api --tail 20 --timestamps 2>/dev/null || \
    echo "No hay logs disponibles aún"
}

# ── DEMO 6: Reducir réplicas y volver a 3 ─────────────────────────────
demo_reducir() {
    header "DEMO 6 — Reducir réplicas"
    echo "Reduciendo de 6 a 3 réplicas..."
    docker service scale swarm_api=3
    sleep 5
    docker service ps swarm_api --format "table {{.Name}}\t{{.CurrentState}}"
    echo ""
    echo -e "${GREEN}✅ Swarm eliminó las réplicas extra gracefully${RESET}"
}

# ── DEMO 7: Inspeccionar la red overlay ────────────────────────────────
demo_red() {
    header "DEMO 7 — Red Overlay de Swarm"
    echo "Redes del stack:"
    docker network ls --filter name=swarm
    echo ""
    echo "Detalles de la overlay network:"
    docker network inspect swarm_swarm-net 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps({'Name':d[0]['Name'],'Driver':d[0]['Driver'],'Scope':d[0]['Scope'],'Containers':list(d[0].get('Containers',{}).values())[:3]}, indent=2))" 2>/dev/null || \
        docker network inspect swarm_swarm-net 2>/dev/null | head -30
}

# ── MENU ────────────────────────────────────────────────────────────────
case "${1:-menu}" in
    1|balanceo)           demo_balanceo ;;
    2|escalar)            demo_escalar ;;
    3|ha|disponibilidad)  demo_alta_disponibilidad ;;
    4|update)             demo_rolling_update ;;
    5|logs)               demo_logs ;;
    6|reducir)            demo_reducir ;;
    7|red)                demo_red ;;
    menu|*)
        header "SwarmShop — Menú de Demos"
        echo "  ./demo.sh 1   — Balanceo de carga visible"
        echo "  ./demo.sh 2   — Escalar API a 6 réplicas"
        echo "  ./demo.sh 3   — Alta disponibilidad (matar contenedor)"
        echo "  ./demo.sh 4   — Rolling update sin downtime"
        echo "  ./demo.sh 5   — Ver logs de todas las réplicas"
        echo "  ./demo.sh 6   — Reducir réplicas"
        echo "  ./demo.sh 7   — Inspeccionar red overlay"
        echo ""
        ;;
esac
