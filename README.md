# irvinbot-infra

Infraestructura de Irvinbot. Contiene el `docker-compose.yml` para levantar todos los microservicios con un solo comando, las variables de entorno compartidas y el script de inicialización de bases de datos.

---

## Arquitectura

```
  Frontend (Vite)           irvinbot-infra (Docker)
  localhost:5173  ────►  gateway :8000
                            ├── auth    :8001   ──►  postgres :5432
                            ├── chat    :8002   ──►  postgres + chromadb + LLM
                            └── docs    :8003   ──►  postgres + chromadb + embeddings
```

| Servicio     | Puerto host | Descripción |
|--------------|-------------|-------------|
| `gateway`    | **8000**    | Único punto de entrada — el front solo habla con este |
| `auth`       | 8001        | Acceso directo (debug) |
| `chat`       | 8002        | Acceso directo (debug) |
| `docs`       | 8003        | Acceso directo (debug) |
| `chromadb`   | 8004        | Base vectorial (RAG de documentos) |
| `postgres`   | 5433        | PostgreSQL (5433 para no chocar con instancia local) |

---

## Proveedores de IA soportados

El sistema soporta múltiples proveedores. Cambiar de proveedor solo requiere editar el `.env` y hacer `docker compose up --build`.

### LLM (para el chat)

| `LLM_PROVIDER` | Modelo por defecto            | Coste   | Requiere                          |
|----------------|-------------------------------|---------|-----------------------------------|
| `ollama`       | `llama3.2`                    | Gratis  | Ollama corriendo en tu Mac        |
| `groq`         | `llama-3.3-70b-versatile`     | Gratis* | `GROQ_API_KEY` (console.groq.com) |
| `openai`       | `gpt-4o`                      | Pago    | `OPENAI_API_KEY`                  |
| `anthropic`    | `claude-sonnet-4-6`           | Pago    | `ANTHROPIC_API_KEY`               |

### Embeddings (para el RAG de documentos)

| `EMBEDDING_PROVIDER` | Modelo por defecto          | Coste   | Requiere                   |
|----------------------|-----------------------------|---------|----------------------------|
| `ollama`             | `nomic-embed-text`          | Gratis  | Ollama corriendo en tu Mac |
| `openai`             | `text-embedding-3-small`    | Pago    | `OPENAI_API_KEY`           |

> *Groq tiene un tier gratuito generoso. Regístrate en [console.groq.com](https://console.groq.com) y copia tu API key.

---

## Requisitos previos

- **Docker Desktop** (o Docker Engine + Compose v2)
- Los repos al mismo nivel:
  ```
  UNIVERSIDAD/
    irvinbot-infra/      ← este repo
    irvinbot-auth/
    irvinbot-chat/
    irvinbot-docs/
    irvinbot-gateway/
    irvinbot-frontend/
  ```

---

## Guía de inicio rápido

### Paso 1 — Copiar el `.env`

```bash
cd irvinbot-infra
cp .env.example .env
```

### Paso 2 — Elegir tu proveedor de IA y completar el `.env`

Abre `.env` y configura según el proveedor que quieras usar:

---

#### Opción A: Groq (recomendado para empezar — gratis, sin instalar nada)

1. Crea una cuenta en [console.groq.com](https://console.groq.com) y genera una API key.
2. En el `.env`:

```dotenv
LLM_PROVIDER=groq
GROQ_API_KEY=gsk_...          # tu clave de Groq

EMBEDDING_PROVIDER=openai
OPENAI_API_KEY=sk-...         # necesaria para embeddings
```

---

#### Opción B: Ollama (completamente gratis y local, sin límites de uso)

1. Instala Ollama:
   ```bash
   brew install ollama
   ```
2. Descarga los modelos (solo la primera vez):
   ```bash
   ollama pull llama3.2          # ~2 GB  — modelo de chat
   ollama pull nomic-embed-text  # ~274 MB — modelo de embeddings
   ```
3. Asegúrate de que Ollama esté corriendo:
   ```bash
   brew services start ollama
   # o simplemente:
   ollama serve
   ```
4. En el `.env`:
   ```dotenv
   LLM_PROVIDER=ollama
   EMBEDDING_PROVIDER=ollama
   OLLAMA_BASE_URL=http://host.docker.internal:11434
   ```
   > `host.docker.internal` apunta automáticamente a tu Mac desde dentro de los contenedores Docker.

---

#### Opción C: OpenAI / Anthropic (pago)

```dotenv
# OpenAI
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-...
EMBEDDING_PROVIDER=openai

# Anthropic
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-...
EMBEDDING_PROVIDER=openai     # Anthropic no tiene embeddings, usa OpenAI
OPENAI_API_KEY=sk-...
```

---

### Paso 3 — Levantar todos los servicios

```bash
cd irvinbot-infra
docker compose up --build
```

La primera vez tarda ~5-10 minutos descargando imágenes y compilando. Cuando veas esto, todo está listo:

```
irvinbot-infra-gateway-1  | INFO: Application startup complete.
irvinbot-infra-auth-1     | INFO: Application startup complete.
irvinbot-infra-chat-1     | INFO: Application startup complete.
irvinbot-infra-docs-1     | INFO: Application startup complete.
```

### Paso 4 — Levantar el frontend

En otra terminal:

```bash
cd irvinbot-frontend
npm install      # solo la primera vez
npm run dev
# → http://localhost:5173
```

Abre el navegador en **http://localhost:5173** y ya puedes registrarte y chatear.

---

## Uso diario

```bash
# Levantar en foreground (ver logs)
docker compose up

# Levantar en background
docker compose up -d

# Parar sin borrar datos
docker compose down

# Parar Y borrar todos los datos (PostgreSQL, ChromaDB, uploads)
docker compose down -v

# Ver logs de un servicio específico
docker compose logs -f chat

# Reconstruir solo un servicio tras cambios en el código
docker compose up --build chat
docker compose up --build docs

# Reiniciar un servicio sin rebuild
docker compose restart gateway
```

---

## Variables de entorno

El `.env` en este directorio es leído por todos los contenedores via `env_file: .env`.

| Variable | Obligatoria | Descripción |
|----------|-------------|-------------|
| `POSTGRES_USER` | Sí | Usuario de PostgreSQL |
| `POSTGRES_PASSWORD` | Sí | Contraseña de PostgreSQL |
| `SECRET_KEY` | **Sí — crítica** | Clave JWT compartida por todos los servicios. Debe ser idéntica en auth, chat, docs y gateway |
| `LLM_PROVIDER` | Sí | `ollama` / `groq` / `openai` / `anthropic` |
| `LLM_MODEL` | No | Override del modelo (vacío = default del proveedor) |
| `EMBEDDING_PROVIDER` | Sí | `ollama` / `openai` |
| `EMBEDDING_MODEL` | No | Override del modelo de embeddings |
| `GROQ_API_KEY` | Si `LLM_PROVIDER=groq` | API key de Groq |
| `ANTHROPIC_API_KEY` | Si `LLM_PROVIDER=anthropic` | API key de Anthropic |
| `OPENAI_API_KEY` | Si usa OpenAI (LLM o embeddings) | API key de OpenAI |
| `OLLAMA_BASE_URL` | Si usa Ollama | URL de Ollama. En Docker en Mac: `http://host.docker.internal:11434` |
| `CHROMA_COLLECTION` | No | Nombre de colección en ChromaDB (default: `thesis_docs`) |
| `MAX_FILE_SIZE_MB` | No | Tamaño máximo de PDF en MB (default: `50`) |

> **CRÍTICO:** `SECRET_KEY` debe ser la misma en todos los servicios. Si difiere, los tokens JWT generados por `auth` serán rechazados por `chat`, `docs` y `gateway`.

---

## Persistencia de datos

Los datos se guardan en volúmenes Docker nombrados que **sobreviven** a `docker compose down`:

| Volumen | Contenido |
|---------|-----------|
| `postgres_data` | Usuarios, sesiones de chat, mensajes, documentos |
| `chroma_data` | Vectores e índices de los PDFs subidos |
| `uploads_data` | Archivos PDF originales |

Para **borrar todos los datos** y empezar desde cero:
```bash
docker compose down -v
```

---

## Comandos de diagnóstico

```bash
# Estado de todos los contenedores
docker compose ps

# Verificar que el gateway responde
curl http://localhost:8000/health

# Verificar que auth responde
curl http://localhost:8001/health

# Ver bases de datos creadas en PostgreSQL
docker compose exec postgres psql -U postgres -c "\l"

# Verificar ChromaDB
curl http://localhost:8004/api/v1/heartbeat

# Ver colecciones de vectores
curl http://localhost:8004/api/v1/collections
```

---

## Resolución de problemas comunes

### El puerto 5432 ya está en uso
El `docker-compose.yml` expone PostgreSQL en el puerto **5433** del host precisamente para evitar conflictos con instancias locales. Si también tienes el 5433 ocupado, edita `docker-compose.yml`:
```yaml
postgres:
  ports:
    - "5434:5432"   # cambia 5433 por otro puerto libre
```

### El chat no responde (se queda pensando)
El LLM no está disponible. Comprueba:
- **Ollama:** ¿está corriendo en tu Mac? → `curl http://localhost:11434` debe responder
- **Ollama:** ¿el modelo está descargado? → `ollama list` debe mostrar `llama3.2`
- **Groq/OpenAI/Anthropic:** ¿la API key es correcta? → revisa el `.env`
- Ver logs del chat: `docker compose logs -f chat`

### Error "Secret key mismatch" o 401 en /auth/me
La `SECRET_KEY` del `.env` no coincide con la que tenían los servicios al generar los tokens. Borra las cookies/localStorage del navegador y vuelve a iniciar sesión.

### ChromaDB unhealthy al arrancar
Puede tardar ~15 segundos en arrancar. Si falla con `service_started`, ejecuta:
```bash
docker compose restart chromadb
docker compose restart chat docs
```
