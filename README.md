# 📊 Contact Center Database — SQL Server

Modelo de base de datos relacional para la gestión de operaciones, RRHH y analytics de un Contact Center, con foco en el análisis de NPS (Net Promoter Score) y métricas de satisfacción del cliente.

---

## 🏗️ Arquitectura del modelo

El proyecto utiliza **3 esquemas** que representan áreas de negocio independientes:

| Esquema | Descripción |
|---|---|
| `rrhh` | Estructura organizacional: programas, supervisores y representantes |
| `operaciones` | Transacciones del día a día: gestiones y encuestas NPS |
| `analytics` | Capa de reportería: vistas y KPIs calculados |

### Diagrama de relaciones

```
rrhh.Programas
    └── rrhh.Supervisores
            └── rrhh.Representantes
                    └── operaciones.Gestiones
                            ├── operaciones.TiposGestion
                            ├── operaciones.Negocios
                            └── operaciones.EncuestasNPS
```

---

## 📁 Estructura del repositorio

```
contact-center-db/
│
├── contact_center_db.sql     # Script principal (DDL + DML + permisos)
└── README.md                 # Documentación del proyecto
```

---

## 🚀 Cómo ejecutar

### Requisitos
- SQL Server 2019 o superior
- Permisos para crear bases de datos

### Pasos
```sql
-- 1. Ejecutar el script completo en SQL Server Management Studio (SSMS)
--    o Azure Data Studio

-- 2. Verificar con las consultas de validación al final del script
SELECT * FROM analytics.vw_NPS_por_Representante;
SELECT * FROM analytics.vw_NPS_Semanal;
EXEC analytics.sp_ResumenRepresentante @login_ccms = 'User162';
```

---

## 🗄️ Tablas

### Esquema `rrhh`

#### `rrhh.Programas`
| Columna | Tipo | Descripción |
|---|---|---|
| id_programa | INT PK | Identificador único |
| nombre | VARCHAR(100) | Nombre del programa/cuenta |
| lob | VARCHAR(100) | Line of Business |
| sublob | VARCHAR(100) | Sub-línea de negocio |
| activo | BIT | Estado del programa |
| fecha_inicio | DATE | Inicio de operaciones |
| fecha_fin | DATE | Fin de operaciones (nullable) |

#### `rrhh.Supervisores`
| Columna | Tipo | Descripción |
|---|---|---|
| id_supervisor | INT PK | Identificador único |
| nombre | VARCHAR(100) | Nombre |
| apellido | VARCHAR(100) | Apellido |
| login_ccms | VARCHAR(50) | Login en sistema operativo (único) |
| id_programa | INT FK | Programa al que pertenece |
| activo | BIT | Estado del supervisor |
| fecha_ingreso | DATE | Fecha de ingreso |

#### `rrhh.Representantes`
| Columna | Tipo | Descripción |
|---|---|---|
| id_representante | INT PK | Identificador único |
| idccms | INT | ID en sistema interno (único) |
| login_ccms | VARCHAR(50) | Login operativo (único) |
| nombre | VARCHAR(100) | Nombre |
| apellido | VARCHAR(100) | Apellido |
| id_supervisor | INT FK | Supervisor asignado |
| id_programa | INT FK | Programa al que pertenece |
| position | VARCHAR(50) | Rol (Representative, Supervisor, etc.) |
| activo | BIT | Estado del representante |
| fecha_ingreso | DATE | Fecha de ingreso |

---

### Esquema `operaciones`

#### `operaciones.Gestiones`
| Columna | Tipo | Descripción |
|---|---|---|
| id_gestion | INT PK | Identificador único |
| id_representante | INT FK | Agente que atendió |
| id_tipo_gestion | INT FK | Canal (Telefónico, RRSS) |
| id_negocio | INT FK | Área de negocio |
| fecha_inicio | DATETIME2 | Inicio de la interacción |
| fecha_fin | DATETIME2 | Fin de la interacción |
| fecha_gestion | DATE | Fecha de gestión |
| tabulacion1-4 | VARCHAR(200) | Motivos de contacto |

#### `operaciones.EncuestasNPS`
| Columna | Tipo | Descripción |
|---|---|---|
| id_encuesta | INT PK | Identificador único |
| id_gestion | INT FK UNIQUE | Gestión asociada (1 encuesta por gestión) |
| puntaje_nps | TINYINT | Puntaje 0-10 |
| grupo_nps | Computed | Promotor / Pasivo / Detractor (calculado) |
| resolucion | VARCHAR(5) | Si / No |
| cordialidad | TINYINT | Satisfacción 1-5 |
| claridad_info | TINYINT | Satisfacción 1-5 |
| conocimiento_rep | TINYINT | Satisfacción 1-5 |
| fecha_encuesta | DATE | Fecha de la encuesta |

---

### Esquema `analytics`

#### Vistas disponibles

| Vista | Descripción |
|---|---|
| `vw_NPS_por_Representante` | KPIs de NPS, resolución y satisfacción por agente |
| `vw_NPS_Semanal` | Evolución semanal del NPS Score |
| `vw_KPIs_por_Negocio` | NPS y resolución por negocio y canal |

#### Stored Procedures

| SP | Descripción |
|---|---|
| `sp_ResumenRepresentante` | Resumen de KPIs de un agente por login |
| `sp_InsertarEncuesta` | Inserción validada de encuestas NPS |

---

## 🔐 Roles y permisos

| Rol | Permisos |
|---|---|
| `rol_analista` | SELECT en `analytics`, EXECUTE en SPs de analytics |
| `rol_operaciones` | SELECT/INSERT en `operaciones`, SELECT en `rrhh` |

---

## 📈 KPIs calculados

### NPS Score
```
NPS Score = (% Promotores - % Detractores) × 100
```
- **Promotores**: puntaje 9-10
- **Pasivos**: puntaje 7-8
- **Detractores**: puntaje 0-6

### % Resolución
```
% Resolución = (Casos resueltos / Total encuestas) × 100
```

---

## 💡 Decisiones de diseño

**¿Por qué separar gestiones de encuestas?**
No toda gestión genera una encuesta NPS. Separar las tablas mantiene la granularidad correcta y evita valores nulos masivos en la tabla principal.

**¿Por qué `grupo_nps` es una columna calculada persistida?**
Permite filtrar y agrupar por grupo NPS sin recalcular en cada consulta, mejorando la performance en tablas grandes.

**¿Por qué usar esquemas separados?**
Facilita la gestión de permisos por área, mejora la organización del código y permite escalar el modelo agregando nuevos esquemas sin afectar los existentes.

**¿Por qué usar vistas en lugar de consultas directas?**
Las vistas encapsulan la lógica de negocio, simplifican las consultas para los analistas y permiten modificar la lógica sin cambiar las aplicaciones que las consumen.

---

## 🛠️ Tecnologías

![SQL Server](https://img.shields.io/badge/SQL%20Server-CC2927?style=for-the-badge&logo=microsoft-sql-server&logoColor=white)

---

## 👤 Autor

**Guillermo Costilla**
- GitHub: [@Guillermo-Costilla](https://github.com/Guillermo-Costilla)
- LinkedIn: [Guillermo Alejandro Costilla](https://www.linkedin.com/in/guillermo-costilla)
