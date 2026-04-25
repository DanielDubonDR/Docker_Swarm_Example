# 🐳 SwarmShop — Docker Swarm Demo Completa

Demo educativa de Docker Swarm con una máquina, mostrando:
- **API Node.js** con 3 réplicas
- **Frontend web** con dashboard en tiempo real
- **NGINX** como balanceador de carga
- Overlay network interna

---

## Estructura del proyecto

```
Docker_Swarm_Example/
├── api/
│   ├── server.js       ← API REST Node.js (health, products, stress)
│   └── Dockerfile
├── web/
│   ├── index.html      ← Dashboard frontend (muestra balanceo en vivo)
│   └── Dockerfile
├── nginx/
│   ├── nginx.conf      ← Reverse proxy + load balancer
│   └── Dockerfile
├── docker-stack.yml    ← Definición del stack para Swarm
└── scripts/
    ├── setup.sh        ← Setup completo automático
    └── demo.sh         ← Scripts de demo interactiva
```

---

## PASO A PASO MANUAL

### Paso 1 — Construir las imágenes

```bash
# Desde la carpeta raíz del proyecto
docker build -t swarm-demo-api:latest   ./api
docker build -t swarm-demo-web:latest   ./web
docker build -t swarm-demo-nginx:latest ./nginx

# Verificar
docker images | grep swarm-demo
```

### Paso 2 — Inicializar Docker Swarm

```bash
# Inicializar el swarm (convierte esta máquina en Manager)
docker swarm init

# Si tienes múltiples interfaces de red:
docker swarm init --advertise-addr 127.0.0.1

# Verificar que está activo
docker info | grep Swarm
# Debe mostrar: Swarm: active

# Ver los nodos del clúster
docker node ls
```

### Paso 3 — Desplegar el stack

```bash
# Desplegar todos los servicios de una vez
docker stack deploy -c docker-stack.yml swarm

# Verificar que los servicios están corriendo
docker stack services swarm

# Ver las tareas (contenedores individuales)
docker stack ps swarm
```

### Paso 4 — Verificar el estado

```bash
# Ver servicios y réplicas
docker service ls

# Ver réplicas del API específicamente
docker service ps swarm_api

# Ver logs de un servicio (todas las réplicas)
docker service logs swarm_api -f
```

### Paso 5 — Abrir la demo

```
http://localhost:80
```

El dashboard mostrará en tiempo real qué contenedor responde cada request.

---

## DEMOSTRACIONES

### Demo A: Ver el balanceo en la terminal

```bash
# 10 requests seguidos — observa los container IDs distintos
for i in {1..10}; do
  curl -s http://localhost/api/health | python3 -m json.tool | grep container_id
  sleep 0.2
done
```

### Demo B: Escalar el API

```bash
# Escalar a 6 réplicas
docker service scale swarm_api=6

# Observar cómo levanta nuevos contenedores
watch docker service ps swarm_api

# La web detectará los nuevos nodos automáticamente
```

### Demo C: Alta disponibilidad

```bash
# Ver los contenedores corriendo
docker ps --filter name=swarm_api

# Matar uno
docker kill <CONTAINER_ID>

# Observar cómo Swarm lo relanza automáticamente
docker service ps swarm_api
# El contenedor muerto aparecerá como "Shutdown" y uno nuevo como "Running"
```

### Demo D: Rolling Update

```bash
# Actualizar el servicio sin downtime
# (actualiza de 1 en 1, 10s de delay, levanta el nuevo antes de bajar el viejo)
docker service update \
  --update-parallelism 1 \
  --update-delay 10s \
  --update-order start-first \
  --image swarm-demo-api:latest \
  swarm_api

# Mientras se actualiza, el API sigue respondiendo — comprobar:
watch curl -s http://localhost/api/health | grep container_id
```

### Demo E: Inspeccionar la red overlay

```bash
# Ver redes del stack
docker network ls --filter name=swarm

# Detalles de la red overlay (conectividad entre contenedores)
docker network inspect swarm_swarm-net
```

---

## SCRIPTS DE DEMO RÁPIDA

```bash
chmod +x scripts/setup.sh scripts/demo.sh

# Setup completo automatizado
./scripts/setup.sh

# Demostración de balanceo
./scripts/demo.sh 1

# Escalar
./scripts/demo.sh 2

# Simular caída de nodo
./scripts/demo.sh 3

# Rolling update
./scripts/demo.sh 4
```

---

## LIMPIAR TODO

```bash
# Eliminar el stack (todos los contenedores)
docker stack rm swarm

# Salir del swarm
docker swarm leave --force

# Eliminar imágenes
docker rmi swarm-demo-api swarm-demo-web swarm-demo-nginx
```

---

## Endpoints del API

| Endpoint | Descripción |
|---|---|
| `GET /api/health` | Info del contenedor que responde |
| `GET /api/products` | Lista de productos (con info del nodo) |
| `GET /api/products/:id` | Producto por ID |
| `GET /api/stress` | Carga CPU (para demos de recursos) |
| `GET /nginx-health` | Health del balanceador NGINX |
