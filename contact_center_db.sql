-- ============================================================
-- PROYECTO: Contact Center Database
-- DESCRIPCION: Modelo de base de datos para la gestión de
--              operaciones, RRHH y analytics de un Contact Center
-- MOTOR: SQL Server 2019+
-- AUTOR: Guillermo Costilla
-- ============================================================

-- ============================================================
-- 1. CREACION DE LA BASE DE DATOS
-- ============================================================

-- Creamos la base de datos principal del proyecto
-- Se usa IF NOT EXISTS para que el script sea reutilizable
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'ContactCenterDB')
BEGIN
    CREATE DATABASE ContactCenterDB;
END
GO

USE ContactCenterDB;
GO

-- ============================================================
-- 2. CREACION DE ESQUEMAS
-- Cada esquema representa un area de negocio distinta.
-- Esto permite organizar los objetos, aplicar permisos
-- por area y facilitar el mantenimiento.
-- ============================================================

-- Esquema para todo lo relacionado a las operaciones del CC
-- (gestiones, encuestas, tabulaciones)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'operaciones')
    EXEC('CREATE SCHEMA operaciones');
GO

-- Esquema para recursos humanos
-- (agentes, supervisores, programas, equipos)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'rrhh')
    EXEC('CREATE SCHEMA rrhh');
GO

-- Esquema para analytics y reporteria
-- (vistas, KPIs, reportes calculados)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'analytics')
    EXEC('CREATE SCHEMA analytics');
GO

-- ============================================================
-- 3. ESQUEMA RRHH
-- Contiene las tablas maestras de personas y estructura
-- organizacional del Contact Center
-- ============================================================

-- Tabla de programas/cuentas del CC
-- Cada programa es un cliente o servicio que se opera
CREATE TABLE rrhh.Programas (
    id_programa     INT IDENTITY(1,1) PRIMARY KEY,
    nombre          VARCHAR(100)    NOT NULL,
    lob             VARCHAR(100),   -- Line of Business
    sublob          VARCHAR(100),   -- Sub-linea de negocio
    activo          BIT             NOT NULL DEFAULT 1,
    fecha_inicio    DATE            NOT NULL,
    fecha_fin       DATE            NULL,
    CONSTRAINT chk_fechas_programa CHECK (fecha_fin IS NULL OR fecha_fin > fecha_inicio)
);
GO

-- Tabla de supervisores
-- Un supervisor lidera un equipo de representantes
CREATE TABLE rrhh.Supervisores (
    id_supervisor   INT IDENTITY(1,1) PRIMARY KEY,
    nombre          VARCHAR(100)    NOT NULL,
    apellido        VARCHAR(100)    NOT NULL,
    login_ccms      VARCHAR(50)     NOT NULL UNIQUE,
    id_programa     INT             NOT NULL,
    activo          BIT             NOT NULL DEFAULT 1,
    fecha_ingreso   DATE            NOT NULL,
    CONSTRAINT fk_supervisor_programa FOREIGN KEY (id_programa)
        REFERENCES rrhh.Programas(id_programa)
);
GO

-- Tabla de representantes (agentes)
-- Un representante pertenece a un programa y reporta a un supervisor
CREATE TABLE rrhh.Representantes (
    id_representante    INT IDENTITY(1,1) PRIMARY KEY,
    idccms              INT             NOT NULL UNIQUE,    -- ID en sistema interno
    login_ccms          VARCHAR(50)     NOT NULL UNIQUE,   -- Login operativo
    nombre              VARCHAR(100)    NOT NULL,
    apellido            VARCHAR(100)    NOT NULL,
    id_supervisor       INT             NOT NULL,
    id_programa         INT             NOT NULL,
    position            VARCHAR(50)     NOT NULL DEFAULT 'Representative',
    activo              BIT             NOT NULL DEFAULT 1,
    fecha_ingreso       DATE            NOT NULL,
    CONSTRAINT fk_rep_supervisor FOREIGN KEY (id_supervisor)
        REFERENCES rrhh.Supervisores(id_supervisor),
    CONSTRAINT fk_rep_programa FOREIGN KEY (id_programa)
        REFERENCES rrhh.Programas(id_programa),
    CONSTRAINT chk_position CHECK (position IN (
        'Representative', 'Supervisor', 'Trainer',
        'Quality Assurance', 'Analista de QA', 'Team Lead'
    ))
);
GO

-- ============================================================
-- 4. ESQUEMA OPERACIONES
-- Contiene las transacciones del dia a dia del CC:
-- gestiones, encuestas NPS y tabulaciones
-- ============================================================

-- Tabla de tipos de gestion (canal de atencion)
CREATE TABLE operaciones.TiposGestion (
    id_tipo_gestion INT IDENTITY(1,1) PRIMARY KEY,
    nombre          VARCHAR(50)     NOT NULL UNIQUE,   -- Telefonico, RRSS, Chat
    descripcion     VARCHAR(200)
);
GO

-- Tabla de negocios atendidos
CREATE TABLE operaciones.Negocios (
    id_negocio      INT IDENTITY(1,1) PRIMARY KEY,
    nombre          VARCHAR(100)    NOT NULL UNIQUE,  -- Comercial, Administrativo, etc
    descripcion     VARCHAR(200)
);
GO

-- Tabla central de gestiones
-- Cada fila representa una interaccion con un cliente
CREATE TABLE operaciones.Gestiones (
    id_gestion          INT IDENTITY(1,1) PRIMARY KEY,
    id_representante    INT             NOT NULL,
    id_tipo_gestion     INT             NOT NULL,
    id_negocio          INT             NOT NULL,
    fecha_inicio        DATETIME2       NOT NULL,
    fecha_fin           DATETIME2       NOT NULL,
    fecha_gestion       DATE            NOT NULL,
    tabulacion1         VARCHAR(200),   -- Motivo de contacto nivel 1
    tabulacion2         VARCHAR(200),   -- Motivo de contacto nivel 2
    tabulacion3         VARCHAR(200),   -- Motivo de contacto nivel 3
    tabulacion4         VARCHAR(200),   -- Motivo de contacto nivel 4
    CONSTRAINT fk_gestion_rep FOREIGN KEY (id_representante)
        REFERENCES rrhh.Representantes(id_representante),
    CONSTRAINT fk_gestion_tipo FOREIGN KEY (id_tipo_gestion)
        REFERENCES operaciones.TiposGestion(id_tipo_gestion),
    CONSTRAINT fk_gestion_negocio FOREIGN KEY (id_negocio)
        REFERENCES operaciones.Negocios(id_negocio),
    CONSTRAINT chk_fechas_gestion CHECK (fecha_fin > fecha_inicio)
);
GO

-- Tabla de encuestas NPS
-- No toda gestion genera encuesta, por eso es una tabla separada
-- Esto mantiene la granularidad correcta del modelo
CREATE TABLE operaciones.EncuestasNPS (
    id_encuesta         INT IDENTITY(1,1) PRIMARY KEY,
    id_gestion          INT             NOT NULL UNIQUE, -- 1 encuesta por gestion
    puntaje_nps         TINYINT         NOT NULL,        -- 0 a 10
    grupo_nps           AS (                             -- columna calculada
        CASE
            WHEN puntaje_nps >= 9 THEN 'Promotor'
            WHEN puntaje_nps >= 7 THEN 'Pasivo'
            ELSE 'Detractor'
        END
    ) PERSISTED,
    resolucion          VARCHAR(5),                      -- Si / No
    cordialidad         TINYINT,                         -- 1 a 5
    claridad_info       TINYINT,                         -- 1 a 5
    conocimiento_rep    TINYINT,                         -- 1 a 5
    fecha_encuesta      DATE            NOT NULL,
    CONSTRAINT fk_encuesta_gestion FOREIGN KEY (id_gestion)
        REFERENCES operaciones.Gestiones(id_gestion),
    CONSTRAINT chk_puntaje_nps CHECK (puntaje_nps BETWEEN 0 AND 10),
    CONSTRAINT chk_resolucion CHECK (resolucion IN ('Si', 'No', NULL)),
    CONSTRAINT chk_cordialidad CHECK (cordialidad BETWEEN 1 AND 5),
    CONSTRAINT chk_claridad CHECK (claridad_info BETWEEN 1 AND 5),
    CONSTRAINT chk_conocimiento CHECK (conocimiento_rep BETWEEN 1 AND 5)
);
GO

-- ============================================================
-- 5. ESQUEMA ANALYTICS
-- Contiene vistas y objetos para reporteria y analisis.
-- Separa la capa de presentacion de la capa operacional.
-- ============================================================

-- Vista: Resumen NPS por representante
-- Calcula los KPIs principales de cada agente
CREATE OR ALTER VIEW analytics.vw_NPS_por_Representante AS
SELECT
    r.login_ccms                                AS Representante,
    r.nombre + ' ' + r.apellido                 AS NombreCompleto,
    s.nombre + ' ' + s.apellido                 AS Supervisor,
    p.nombre                                    AS Programa,
    COUNT(e.id_encuesta)                        AS TotalEncuestas,
    SUM(CASE WHEN e.grupo_nps = 'Promotor'  THEN 1 ELSE 0 END) AS Promotores,
    SUM(CASE WHEN e.grupo_nps = 'Pasivo'    THEN 1 ELSE 0 END) AS Pasivos,
    SUM(CASE WHEN e.grupo_nps = 'Detractor' THEN 1 ELSE 0 END) AS Detractores,
    -- NPS Score = % Promotores - % Detractores
    CAST(
        (SUM(CASE WHEN e.grupo_nps = 'Promotor'  THEN 1.0 ELSE 0 END) -
         SUM(CASE WHEN e.grupo_nps = 'Detractor' THEN 1.0 ELSE 0 END))
        / NULLIF(COUNT(e.id_encuesta), 0) * 100
    AS DECIMAL(5,2))                            AS NPS_Score,
    -- % Resolucion
    CAST(
        SUM(CASE WHEN e.resolucion = 'Si' THEN 1.0 ELSE 0 END)
        / NULLIF(COUNT(e.id_encuesta), 0) * 100
    AS DECIMAL(5,2))                            AS Pct_Resolucion,
    -- Promedios de satisfaccion
    CAST(AVG(CAST(e.cordialidad AS DECIMAL(5,2)))       AS DECIMAL(4,2)) AS Prom_Cordialidad,
    CAST(AVG(CAST(e.claridad_info AS DECIMAL(5,2)))     AS DECIMAL(4,2)) AS Prom_Claridad,
    CAST(AVG(CAST(e.conocimiento_rep AS DECIMAL(5,2)))  AS DECIMAL(4,2)) AS Prom_Conocimiento
FROM rrhh.Representantes r
JOIN rrhh.Supervisores s        ON r.id_supervisor = s.id_supervisor
JOIN rrhh.Programas p           ON r.id_programa = p.id_programa
LEFT JOIN operaciones.Gestiones g   ON r.id_representante = g.id_representante
LEFT JOIN operaciones.EncuestasNPS e ON g.id_gestion = e.id_gestion
GROUP BY
    r.login_ccms, r.nombre, r.apellido,
    s.nombre, s.apellido, p.nombre;
GO

-- Vista: Evolucion NPS semanal
-- Muestra la tendencia del NPS por semana para graficos de linea
CREATE OR ALTER VIEW analytics.vw_NPS_Semanal AS
SELECT
    -- Lunes de cada semana como identificador
    DATEADD(DAY, -(DATEPART(WEEKDAY, e.fecha_encuesta) - 2 + 7) % 7,
        e.fecha_encuesta)                       AS Semana,
    COUNT(e.id_encuesta)                        AS TotalEncuestas,
    SUM(CASE WHEN e.grupo_nps = 'Promotor'  THEN 1 ELSE 0 END) AS Promotores,
    SUM(CASE WHEN e.grupo_nps = 'Detractor' THEN 1 ELSE 0 END) AS Detractores,
    CAST(
        (SUM(CASE WHEN e.grupo_nps = 'Promotor'  THEN 1.0 ELSE 0 END) -
         SUM(CASE WHEN e.grupo_nps = 'Detractor' THEN 1.0 ELSE 0 END))
        / NULLIF(COUNT(e.id_encuesta), 0) * 100
    AS DECIMAL(5,2))                            AS NPS_Score
FROM operaciones.EncuestasNPS e
GROUP BY
    DATEADD(DAY, -(DATEPART(WEEKDAY, e.fecha_encuesta) - 2 + 7) % 7,
        e.fecha_encuesta);
GO

-- Vista: KPIs por negocio y canal
CREATE OR ALTER VIEW analytics.vw_KPIs_por_Negocio AS
SELECT
    n.nombre                                    AS Negocio,
    tg.nombre                                   AS Canal,
    COUNT(e.id_encuesta)                        AS TotalEncuestas,
    CAST(
        (SUM(CASE WHEN e.grupo_nps = 'Promotor'  THEN 1.0 ELSE 0 END) -
         SUM(CASE WHEN e.grupo_nps = 'Detractor' THEN 1.0 ELSE 0 END))
        / NULLIF(COUNT(e.id_encuesta), 0) * 100
    AS DECIMAL(5,2))                            AS NPS_Score,
    CAST(
        SUM(CASE WHEN e.resolucion = 'Si' THEN 1.0 ELSE 0 END)
        / NULLIF(COUNT(e.id_encuesta), 0) * 100
    AS DECIMAL(5,2))                            AS Pct_Resolucion
FROM operaciones.Negocios n
JOIN operaciones.Gestiones g        ON n.id_negocio = g.id_negocio
JOIN operaciones.TiposGestion tg    ON g.id_tipo_gestion = tg.id_tipo_gestion
LEFT JOIN operaciones.EncuestasNPS e ON g.id_gestion = e.id_gestion
GROUP BY n.nombre, tg.nombre;
GO

-- ============================================================
-- 6. STORED PROCEDURES
-- ============================================================

-- SP: Obtener resumen de un representante especifico
CREATE OR ALTER PROCEDURE analytics.sp_ResumenRepresentante
    @login_ccms VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        DECLARE @total_encuestas    INT
        DECLARE @nps_score          DECIMAL(5,2)
        DECLARE @pct_resolucion     DECIMAL(5,2)
        DECLARE @nombre             VARCHAR(200)

        SELECT
            @total_encuestas    = TotalEncuestas,
            @nps_score          = NPS_Score,
            @pct_resolucion     = Pct_Resolucion,
            @nombre             = NombreCompleto
        FROM analytics.vw_NPS_por_Representante
        WHERE Representante = @login_ccms;

        IF @nombre IS NULL
        BEGIN
            RAISERROR('El representante %s no existe.', 16, 1, @login_ccms);
            RETURN;
        END

        SELECT
            @nombre             AS Representante,
            @total_encuestas    AS TotalEncuestas,
            @nps_score          AS NPS_Score,
            @pct_resolucion     AS Pct_Resolucion,
            CASE
                WHEN @nps_score >= 70 THEN 'Alto rendimiento'
                WHEN @nps_score >= 50 THEN 'Rendimiento normal'
                ELSE 'Requiere seguimiento'
            END                 AS Clasificacion;

    END TRY
    BEGIN CATCH
        SELECT
            ERROR_MESSAGE() AS MensajeError,
            ERROR_LINE()    AS Linea,
            ERROR_NUMBER()  AS NumeroError;
    END CATCH
END;
GO

-- SP: Insertar nueva encuesta NPS con validaciones
CREATE OR ALTER PROCEDURE operaciones.sp_InsertarEncuesta
    @id_gestion         INT,
    @puntaje_nps        TINYINT,
    @resolucion         VARCHAR(5)  = NULL,
    @cordialidad        TINYINT     = NULL,
    @claridad_info      TINYINT     = NULL,
    @conocimiento_rep   TINYINT     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION

            -- Validar que la gestion existe
            IF NOT EXISTS (SELECT 1 FROM operaciones.Gestiones WHERE id_gestion = @id_gestion)
                RAISERROR('La gestion %d no existe.', 16, 1, @id_gestion);

            -- Validar que no tenga encuesta ya
            IF EXISTS (SELECT 1 FROM operaciones.EncuestasNPS WHERE id_gestion = @id_gestion)
                RAISERROR('La gestion %d ya tiene una encuesta registrada.', 16, 1, @id_gestion);

            INSERT INTO operaciones.EncuestasNPS (
                id_gestion, puntaje_nps, resolucion,
                cordialidad, claridad_info, conocimiento_rep, fecha_encuesta
            )
            VALUES (
                @id_gestion, @puntaje_nps, @resolucion,
                @cordialidad, @claridad_info, @conocimiento_rep, CAST(GETDATE() AS DATE)
            );

        COMMIT TRANSACTION
        PRINT 'Encuesta registrada correctamente.';

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
        SELECT
            ERROR_MESSAGE() AS MensajeError,
            ERROR_LINE()    AS Linea;
    END CATCH
END;
GO

-- ============================================================
-- 7. INDICES
-- Los indices mejoran la performance de las consultas mas
-- frecuentes en el sistema de reporteria
-- ============================================================

-- Indice en fecha_gestion para consultas temporales
CREATE NONCLUSTERED INDEX IX_Gestiones_Fecha
ON operaciones.Gestiones(fecha_gestion);
GO

-- Indice en grupo_nps para filtros frecuentes en reportes
CREATE NONCLUSTERED INDEX IX_Encuestas_GrupoNPS
ON operaciones.EncuestasNPS(grupo_nps)
INCLUDE (puntaje_nps, resolucion, fecha_encuesta);
GO

-- Indice en id_representante para JOINs frecuentes
CREATE NONCLUSTERED INDEX IX_Gestiones_Representante
ON operaciones.Gestiones(id_representante)
INCLUDE (id_tipo_gestion, id_negocio, fecha_gestion);
GO

-- ============================================================
-- 8. ROLES Y PERMISOS
-- Separamos los permisos por perfil de usuario:
-- - rol_analista: solo lectura en analytics
-- - rol_operaciones: lectura/escritura en operaciones
-- - rol_admin: acceso total
-- ============================================================

-- Crear roles
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_analista')
    CREATE ROLE rol_analista;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_operaciones')
    CREATE ROLE rol_operaciones;
GO

-- Permisos rol_analista: solo puede leer vistas y ejecutar SPs de analytics
GRANT SELECT ON SCHEMA::analytics TO rol_analista;
GRANT EXECUTE ON analytics.sp_ResumenRepresentante TO rol_analista;
GO

-- Permisos rol_operaciones: puede leer y escribir en operaciones
GRANT SELECT, INSERT ON SCHEMA::operaciones TO rol_operaciones;
GRANT EXECUTE ON operaciones.sp_InsertarEncuesta TO rol_operaciones;
GRANT SELECT ON SCHEMA::rrhh TO rol_operaciones;
GO

-- ============================================================
-- 9. DATOS DE EJEMPLO
-- Insertamos datos de prueba para validar el modelo
-- ============================================================

-- Programas
INSERT INTO rrhh.Programas (nombre, lob, sublob, fecha_inicio)
VALUES
    ('Combustible X RCQST Agentes B2B', 'Combustible X B2B', 'Telefonico',    '2023-01-01'),
    ('Combustible X TCMN2 Agentes',     'Combustible X',     'Redes Sociales','2023-01-01'),
    ('Combustible X RCQST Supervisores','Combustible X B2B', 'Telefonico',    '2023-01-01');
GO

-- Supervisores
INSERT INTO rrhh.Supervisores (nombre, apellido, login_ccms, id_programa, fecha_ingreso)
VALUES
    ('Supervisor', '32', 'Supervisor32', 1, '2022-01-01'),
    ('Supervisor', '11', 'Supervisor11', 2, '2022-01-01'),
    ('Supervisor', '42', 'Supervisor42', 1, '2022-01-01');
GO

-- Representantes
INSERT INTO rrhh.Representantes (idccms, login_ccms, nombre, apellido, id_supervisor, id_programa, fecha_ingreso)
VALUES
    (8119922, 'User162', 'Colaborador', '125', 1, 1, '2023-01-15'),
    (8119961, 'User354', 'Colaborador', '61',  1, 1, '2023-01-15'),
    (3881388, 'User389', 'Colaborador', '45',  2, 2, '2023-02-01'),
    (8119935, 'User42',  'Colaborador', '94',  1, 1, '2023-02-01');
GO

-- Tipos de gestion
INSERT INTO operaciones.TiposGestion (nombre, descripcion)
VALUES
    ('Telefonico',     'Atencion via llamada telefonica'),
    ('Redes Sociales', 'Atencion via redes sociales y chat digital');
GO

-- Negocios
INSERT INTO operaciones.Negocios (nombre, descripcion)
VALUES
    ('Comercial',        'Gestiones comerciales y ventas'),
    ('Administrativo',   'Gestiones administrativas y consultas'),
    ('Grandes Clientes', 'Atencion a clientes corporativos');
GO

-- Gestiones de ejemplo
INSERT INTO operaciones.Gestiones
    (id_representante, id_tipo_gestion, id_negocio, fecha_inicio, fecha_fin, fecha_gestion, tabulacion1)
VALUES
    (1, 1, 1, '2023-09-04 08:00:00', '2023-09-04 08:08:00', '2023-09-04', 'Cte Convergente Combo'),
    (1, 1, 1, '2023-09-04 09:00:00', '2023-09-04 09:06:00', '2023-09-04', 'Productos/Servicios'),
    (2, 1, 2, '2023-09-04 10:00:00', '2023-09-04 10:05:00', '2023-09-04', 'Cte No Convergente'),
    (3, 2, 1, '2023-09-05 08:30:00', '2023-09-05 08:35:00', '2023-09-05', 'Consulta General'),
    (4, 1, 3, '2023-09-05 09:00:00', '2023-09-05 09:10:00', '2023-09-05', 'Cliente Prepago');
GO

-- Encuestas NPS de ejemplo
INSERT INTO operaciones.EncuestasNPS
    (id_gestion, puntaje_nps, resolucion, cordialidad, claridad_info, conocimiento_rep, fecha_encuesta)
VALUES
    (1, 9,  'Si', 5, 4, 5, '2023-09-04'),
    (2, 8,  'Si', 4, 4, 4, '2023-09-04'),
    (3, 10, 'Si', 5, 5, 5, '2023-09-04'),
    (4, 6,  'No', 3, 3, 3, '2023-09-05'),
    (5, 9,  'Si', 5, 4, 4, '2023-09-05');
GO

-- ============================================================
-- 10. CONSULTAS DE VALIDACION
-- Ejecutar para verificar que todo funciona correctamente
-- ============================================================

-- Ver resumen NPS por representante
SELECT * FROM analytics.vw_NPS_por_Representante;
GO

-- Ver evolucion semanal
SELECT * FROM analytics.vw_NPS_Semanal;
GO

-- Ver KPIs por negocio
SELECT * FROM analytics.vw_KPIs_por_Negocio;
GO

-- Ejecutar SP de resumen
EXEC analytics.sp_ResumenRepresentante @login_ccms = 'User162';
GO
