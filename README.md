# irvinbot-infra

Infraestructura de Irvinbot. Contiene el `docker-compose.yml` para levantar todos los servicios con un solo comando, el archivo de variables de entorno compartidas y el script de inicialización de bases de datos.

---

## Qué contiene

```
irvinbot-infra/
├── docker-compose.yml          ← orquesta los 6 servicios + infraestructura
├── .env.example                ← plantilla de variables de entorno compartidas
└── scripts/
    └── init-databases.sh       ← crea irvinbot_auth, irvinbot_chat, irvinbot_docs en PostgreSQL
```

---

## Arquitectura de contenedores

```
                    ┌─────────────────────────────┐
  Frontend (Vite)   │         irvinbot-infra        │
  localhost:5173 ──►│                               │
                    │  gateway :8000                │
                    │    ├── auth    :8001           │
                    │    ├── chat    :8002 ──► chromadb :8000 (interno)
                    │    └── docs    :8003 ──► chromadb        │
                    │                               │
                    │  postgres  :5432              │
                    │  chromadb  :8000 (interno)    │
                    │            :8004 (host)       │
                    └─────────────────────────────┘
```

**Puertos expuestos al host:**

| Servicio | Puerto host | Descripción |
|----------|-------------|-------------|
| `gateway` | 8000 | Único punto de entrada de la API |
| `auth` | 8001 | Acceso directo (dev/debug) |
| `chat` | 8002 | Acceso directo (dev/debug) |
| `docs` | 8003 | Acceso directo (dev/debug) |
| `chromadb` | 8004 | UI y API de ChromaDB |
| `postgres` | 5432 | Para clientes SQL (TablePlus, DBeaver, etc.) |

---

## Cómo levantar todo

### Prerequisitos
- Docker Desktop o Docker Engine + Docker Compose v2
- Los 4 repos de servicios al mismo nivel que `irvinbot-infra`:
  ```
  UNIVERSIDAD/
    irvinbot-infra/
    irvinbot-auth/
    irvinbot-chat/
    irvinbot-docs/
    irvinbot-gateway/
    irvinbot-frontend/
  ```

### Primera vez
```bash
cd irvinbot-infra

# 1. Copiar y rellenar las variables de entorno
cp .env.example .env
# Editar .env: añadir ANTHROPIC_API_KEY y/o OPENAI_API_KEY, cambiar SECRET_KEY

# 2. Construir imágenes y levantar
docker compose up --build

# Esperar a que aparezca:
# gateway | INFO: Application startup complete.
```

### Uso diario
```bash
docker compose up          # levanta en foreground
docker compose up -d       # levanta en background
docker compose down        # para y elimina contenedores (los volúmenes persisten)
docker compose down -v     # para y ELIMINA VOLÚMENES (borra todos los datos)
```

### Rebuild de un solo servicio
```bash
docker compose up --build auth     # reconstruye solo auth
docker compose restart chat        # reinicia sin rebuild
```

---

## Variables de entorno

El archivo `.env` en este directorio es compartido por todos los servicios via `env_file: .env` en el docker-compose. Cada servicio solo lee las variables que necesita.

| Variable | Obligatoria | Descripción |
|----------|-------------|-------------|
| `POSTGRES_USER` | Sí | Usuario de PostgreSQL |
| `POSTGRES_PASSWORD` | Sí | Contraseña de PostgreSQL |
| `SECRET_KEY` | **Sí** | Clave JWT, **idéntica** en todos los servicios |
| `LLM_PROVIDER` | Sí | `anthropic` o `openai` |
| `ANTHROPIC_API_KEY` | Si usa Anthropic | `sk-ant-...` |
| `OPENAI_API_KEY` | **Siempre** | Para embeddings de ChromaDB |
| `LLM_MODEL` | No | Override del modelo LLM |
| `CHROMA_COLLECTION` | No | Nombre de colección en ChromaDB (default: `thesis_docs`) |
| `MAX_FILE_SIZE_MB` | No | Tamaño máx. de PDF (default: `50`) |

> **CRÍTICO:** `SECRET_KEY` es compartida y debe ser la misma en todos los servicios para que los tokens JWT generados por `auth` sean válidos en `chat`, `docs` y `gateway`.

---

## Inicialización de bases de datos

El script `scripts/init-databases.sh` se monta en `/docker-entrypoint-initdb.d/` del contenedor de PostgreSQL. PostgreSQL lo ejecuta automáticamente la **primera vez** que el volumen está vacío.

El script crea las 3 bases de datos si no existen:
- `irvinbot_auth`
- `irvinbot_chat`
- `irvinbot_docs`

Las tablas dentro de cada base las crean los propios servicios al arrancar via `Base.metadata.create_all(bind=engine)`.

---

## Orden de arranque

El docker-compose garantiza este orden via `depends_on` y healthchecks:

```
1. postgres     → espera hasta que pg_isready responde
2. chromadb     → espera hasta que /api/v1/heartbeat responde
3. auth         → espera a postgres (service_healthy)
   chat         → espera a postgres + chromadb
   docs         → espera a postgres + chromadb
4. gateway      → espera a auth, chat y docs
```

---

## Persistencia de datos

Los datos se guardan en volúmenes Docker nombrados:

| Volumen | Contenido |
|---------|-----------|
| `postgres_data` | Bases de datos PostgreSQL |
| `chroma_data` | Vectores e índices de ChromaDB |
| `uploads_data` | PDFs subidos por los usuarios |

Estos volúmenes **sobreviven** a `docker compose down`. Solo se eliminan con `docker compose down -v`.

---

## Comandos útiles

```bash
# Ver logs de un servicio
docker compose logs -f chat

# Entrar al contenedor de postgres
docker compose exec postgres psql -U postgres -d irvinbot_auth

# Ver colecciones en ChromaDB
curl http://localhost:8004/api/v1/collections

# Verificar que el gateway responde
curl http://localhost:8000/health

# Ver estado de todos los contenedores
docker compose ps
```

---

## Deploy en producción

Para desplegar en Render/Railway (backend) + Vercel (frontend):

1. Cada servicio tiene su propio `Dockerfile`, se despliega de forma independiente
2. Usar una instancia PostgreSQL gestionada (Railway, Supabase, Render PostgreSQL)
3. Usar ChromaDB Cloud o desplegar ChromaDB en Railway con volumen persistente
4. Las variables de entorno se configuran en el dashboard de cada plataforma
5. Actualizar `AUTH_SERVICE_URL`, `CHAT_SERVICE_URL`, `DOCS_SERVICE_URL` en el gateway con las URLs de producción
6. En el frontend, actualizar `VITE_API_URL` con la URL pública del gateway
