-- Initial relational schema.
--
-- Deliberately NOT included (to be added by hand in later migrations):
--   * the `chunk` table (embedding vector + tsvector) and the pgvector extension
--   * every search-related index (HNSW, GIN full-text)

-- Laws ------------------------------------------------------------------

CREATE TABLE ley (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    clave           TEXT NOT NULL UNIQUE,   -- short key, e.g. CPEUM
    nombre          TEXT NOT NULL,
    fuente_url      TEXT,
    ultima_reforma  DATE
);

-- Raw downloaded files. Never overwritten: a new download is a new row.
CREATE TABLE documento_crudo (
    id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ley_id                BIGINT NOT NULL REFERENCES ley (id),
    fecha_reforma         DATE NOT NULL,
    formato               TEXT NOT NULL,        -- e.g. doc, docx, pdf
    ruta_almacenamiento   TEXT NOT NULL,
    hash_archivo          TEXT NOT NULL,
    descargado_en         TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (ley_id, hash_archivo)               -- same content is not stored twice
);

-- Articles and their versions -------------------------------------------

CREATE TABLE articulo (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ley_id            BIGINT NOT NULL REFERENCES ley (id),
    numero            TEXT NOT NULL,            -- text on purpose: "15 bis", "Segundo transitorio", ...
    ruta_estructural  TEXT                      -- title / chapter / section path
);

-- Lookup by law + article number. Not UNIQUE yet: whether (ley_id, numero) is
-- unique depends on how transitory provisions end up being modeled.
CREATE INDEX idx_articulo_ley_numero ON articulo (ley_id, numero);

CREATE TABLE articulo_version (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    articulo_id     BIGINT NOT NULL REFERENCES articulo (id),
    texto           TEXT NOT NULL,
    vigente_desde   DATE NOT NULL,
    vigente_hasta   DATE,                       -- NULL = currently valid
    hash_texto      TEXT NOT NULL,
    fuente_url      TEXT,
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
    UNIQUE (articulo_id, vigente_desde)
);

-- At most one currently valid version per article.
CREATE UNIQUE INDEX uq_articulo_version_vigente
    ON articulo_version (articulo_id)
    WHERE vigente_hasta IS NULL;

CREATE TABLE referencia_cruzada (
    origen_articulo_id   BIGINT NOT NULL REFERENCES articulo (id),
    destino_articulo_id  BIGINT NOT NULL REFERENCES articulo (id),
    PRIMARY KEY (origen_articulo_id, destino_articulo_id)
);

CREATE INDEX idx_referencia_cruzada_destino ON referencia_cruzada (destino_articulo_id);

-- API access and usage --------------------------------------------------

CREATE TABLE api_key (
    id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hash      TEXT NOT NULL UNIQUE,             -- only the hash is stored, never the key
    email     TEXT NOT NULL,
    creada    TIMESTAMPTZ NOT NULL DEFAULT now(),
    activa    BOOLEAN NOT NULL DEFAULT TRUE
);

-- Usage log. Intentionally does not store the query text (it may contain personal data).
CREATE TABLE consulta_log (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    api_key_id        BIGINT REFERENCES api_key (id) ON DELETE SET NULL,
    latencia_ms       INTEGER NOT NULL,
    num_resultados    INTEGER NOT NULL,
    fecha             TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_consulta_log_key_fecha ON consulta_log (api_key_id, fecha);

-- Ingestion runs --------------------------------------------------------

CREATE TABLE ingesta_corrida (
    id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    inicio                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    fin                     TIMESTAMPTZ,
    estado                  TEXT NOT NULL,      -- allowed values to be decided in the application
    leyes_revisadas         INTEGER NOT NULL DEFAULT 0,
    leyes_cambiadas         INTEGER NOT NULL DEFAULT 0,
    articulos_actualizados  INTEGER NOT NULL DEFAULT 0,
    errores                 TEXT
);
