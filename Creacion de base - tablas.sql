-- =========================================================
-- ARCHIVO 1: CREACIÓN DE BASE DE DATOS Y TABLAS (11 tablas en 3FN)
-- =========================================================

CREATE DATABASE RUTA_Puebla;
GO

USE RUTA_Puebla;
GO

-- =========================================================
-- 1. MÓDULO DE INFRAESTRUCTURA Y COBERTURA
-- =========================================================

CREATE TABLE Linea(
    id_linea INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Linea PRIMARY KEY,
    nombre NVARCHAR(80) NOT NULL CONSTRAINT UQ_Linea_nombre UNIQUE,
    color NVARCHAR(20) NOT NULL,
    longitud_km DECIMAL(5,2) NOT NULL,
    recorrido NVARCHAR(200) NOT NULL,
    estado NVARCHAR(20) NOT NULL
        CONSTRAINT DF_Linea_estado DEFAULT N'Activa'
        CONSTRAINT CK_Linea_estado CHECK(estado IN(N'Activa', N'Inactiva', N'En mantenimiento'))
);
GO

CREATE TABLE Paradero(
    id_paradero INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Paradero PRIMARY KEY,
    id_linea INT NOT NULL CONSTRAINT FK_Paradero_Linea REFERENCES Linea(id_linea),
    nombre NVARCHAR(80) NOT NULL,
    orden SMALLINT NOT NULL,
    latitud DECIMAL(9,6) NOT NULL,
    longitud DECIMAL(9,6) NOT NULL,
    tipo NVARCHAR(10) NOT NULL
        CONSTRAINT CK_Paradero_tipo CHECK(tipo IN(N'Troncal', N'Enlace', N'Terminal')),
    id_paradero_enlace INT NULL
        CONSTRAINT FK_Paradero_Enlace REFERENCES Paradero(id_paradero),
    CONSTRAINT UQ_Paradero_linea_nombre UNIQUE(id_linea, nombre),
    CONSTRAINT UQ_Paradero_linea_orden UNIQUE(id_linea, orden),
    CONSTRAINT CK_Paradero_enlace_distinto
        CHECK(id_paradero_enlace IS NULL OR id_paradero_enlace <> id_paradero)
);
GO

CREATE TABLE ReglaTransbordo(
    id_regla INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ReglaTransbordo PRIMARY KEY,
    id_linea_origen INT NOT NULL CONSTRAINT FK_Regla_origen REFERENCES Linea(id_linea),
    id_linea_destino INT NOT NULL CONSTRAINT FK_Regla_destino REFERENCES Linea(id_linea),
    costo DECIMAL(10,2) NOT NULL CONSTRAINT CK_Regla_costo CHECK(costo >= 0),
    vigente_desde DATE NOT NULL,
    vigente_hasta DATE NULL,
    CONSTRAINT UQ_Regla_par UNIQUE(id_linea_origen, id_linea_destino),
    CONSTRAINT CK_Regla_origen_distinto CHECK(id_linea_origen <> id_linea_destino),
    CONSTRAINT CK_Regla_vigencia CHECK(vigente_hasta IS NULL OR vigente_hasta >= vigente_desde)
);
GO

-- =========================================================
-- 2. MÓDULO DE FLOTA Y OPERACIÓN
-- =========================================================

CREATE TABLE Unidad(
    id_unidad INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Unidad PRIMARY KEY,
    numero_economico NVARCHAR(20) NOT NULL CONSTRAINT UQ_Unidad_economico UNIQUE,
    placas NVARCHAR(15) NOT NULL CONSTRAINT UQ_Unidad_placas UNIQUE,
    capacidad SMALLINT NOT NULL CONSTRAINT CK_Unidad_capacidad CHECK(capacidad > 0),
    modelo NVARCHAR(40) NOT NULL,
    anio SMALLINT NOT NULL CONSTRAINT CK_Unidad_anio CHECK(anio BETWEEN 1990 AND 2030),
    estado NVARCHAR(20) NOT NULL
        CONSTRAINT DF_Unidad_estado DEFAULT N'Disponible'
        CONSTRAINT CK_Unidad_estado CHECK(estado IN(N'Disponible', N'En ruta', N'Mantenimiento', N'Fuera de servicio')),
    id_linea_asignada INT NULL CONSTRAINT FK_Unidad_Linea REFERENCES Linea(id_linea)
);
GO

CREATE TABLE Chofer(
    id_chofer INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Chofer PRIMARY KEY,
    nombre NVARCHAR(60) NOT NULL,
    apellido_paterno NVARCHAR(60) NOT NULL,
    apellido_materno NVARCHAR(60) NULL,
    num_licencia NVARCHAR(20) NOT NULL CONSTRAINT UQ_Chofer_licencia UNIQUE,
    tipo_licencia NCHAR(1) NOT NULL
        CONSTRAINT CK_Chofer_licencia CHECK(tipo_licencia IN(N'A', N'B', N'C', N'D', N'E')),
    vigencia_licencia DATE NOT NULL,
    telefono NVARCHAR(15) NULL,
    estado NVARCHAR(12) NOT NULL
        CONSTRAINT DF_Chofer_estado DEFAULT N'Activo'
        CONSTRAINT CK_Chofer_estado CHECK(estado IN(N'Activo', N'Inactivo', N'Suspendido'))
);
GO

CREATE TABLE TurnoTrabajo(
    id_turno INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TurnoTrabajo PRIMARY KEY,
    id_chofer INT NOT NULL CONSTRAINT FK_Turno_Chofer REFERENCES Chofer(id_chofer),
    fecha DATE NOT NULL,
    tipo_turno NVARCHAR(12) NOT NULL
        CONSTRAINT CK_Turno_tipo CHECK(tipo_turno IN(N'Matutino', N'Vespertino', N'Nocturno')),
    hora_inicio TIME(0) NOT NULL,
    hora_fin TIME(0) NOT NULL,
    id_unidad INT NULL CONSTRAINT FK_Turno_Unidad REFERENCES Unidad(id_unidad),
    CONSTRAINT UQ_Turno_chofer_fecha_tipo UNIQUE(id_chofer, fecha, tipo_turno),
    CONSTRAINT CK_Turno_horas_distintas CHECK(hora_inicio <> hora_fin),
    CONSTRAINT CK_Turno_cronologia CHECK(tipo_turno = N'Nocturno' OR hora_fin > hora_inicio)
);
GO

CREATE TABLE BitacoraViaje(
    id_viaje INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_BitacoraViaje PRIMARY KEY,
    id_turno INT NOT NULL CONSTRAINT FK_Bitacora_Turno REFERENCES TurnoTrabajo(id_turno),
    id_unidad INT NOT NULL CONSTRAINT FK_Bitacora_Unidad REFERENCES Unidad(id_unidad),
    id_linea INT NOT NULL CONSTRAINT FK_Bitacora_Linea REFERENCES Linea(id_linea),
    hora_salida DATETIME2(0) NOT NULL,
    hora_llegada DATETIME2(0) NULL,
    pasajeros_transportados INT NOT NULL
        CONSTRAINT DF_Bitacora_pasajeros DEFAULT 0
        CONSTRAINT CK_Bitacora_pasajeros CHECK(pasajeros_transportados >= 0),
    observaciones NVARCHAR(200) NULL,
    CONSTRAINT CK_Bitacora_cronologia CHECK(hora_llegada IS NULL OR hora_llegada > hora_salida)
);
GO

-- =========================================================
-- 3. MÓDULO DE PREPAGO Y ACCESOS
-- =========================================================

CREATE TABLE Usuario(
    id_usuario INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Usuario PRIMARY KEY,
    nombre NVARCHAR(60) NOT NULL,
    apellido_paterno NVARCHAR(60) NOT NULL,
    apellido_materno NVARCHAR(60) NULL,
    correo NVARCHAR(120) NULL CONSTRAINT UQ_Usuario_correo UNIQUE,
    telefono NVARCHAR(15) NULL,
    tipo_perfil NVARCHAR(15) NOT NULL
        CONSTRAINT CK_Usuario_perfil CHECK(tipo_perfil IN(N'General', N'Estudiante', N'Adulto mayor', N'Discapacidad')),
    fecha_registro DATETIME2(0) NOT NULL
        CONSTRAINT DF_Usuario_registro DEFAULT SYSDATETIME()
);
GO

CREATE TABLE Tarjeta(
    id_tarjeta INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Tarjeta PRIMARY KEY,
    id_usuario INT NOT NULL CONSTRAINT FK_Tarjeta_Usuario REFERENCES Usuario(id_usuario),
    codigo_uid NVARCHAR(32) NOT NULL CONSTRAINT UQ_Tarjeta_uid UNIQUE,
    tipo_tarifa NVARCHAR(15) NOT NULL
        CONSTRAINT CK_Tarjeta_tarifa CHECK(tipo_tarifa IN(N'General', N'Estudiante', N'Adulto mayor', N'Discapacidad')),
    saldo DECIMAL(10,2) NOT NULL
        CONSTRAINT DF_Tarjeta_saldo DEFAULT 0
        CONSTRAINT CK_Tarjeta_saldo CHECK(saldo >= 0),
    estado NVARCHAR(12) NOT NULL
        CONSTRAINT DF_Tarjeta_estado DEFAULT N'Activa'
        CONSTRAINT CK_Tarjeta_estado CHECK(estado IN(N'Activa', N'Bloqueada', N'Vencida', N'Baja')),
    fecha_emision DATE NOT NULL
        CONSTRAINT DF_Tarjeta_emision DEFAULT CAST(SYSDATETIME() AS DATE),
    fecha_vencimiento DATE NULL,
    CONSTRAINT CK_Tarjeta_vencimiento CHECK(fecha_vencimiento IS NULL OR fecha_vencimiento >= fecha_emision)
);
GO

CREATE TABLE Recarga(
    id_recarga INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Recarga PRIMARY KEY,
    id_tarjeta INT NOT NULL CONSTRAINT FK_Recarga_Tarjeta REFERENCES Tarjeta(id_tarjeta),
    monto DECIMAL(10,2) NOT NULL CONSTRAINT CK_Recarga_monto CHECK(monto > 0),
    saldo_previo DECIMAL(10,2) NOT NULL,
    saldo_posterior DECIMAL(10,2) NOT NULL,
    fecha_hora DATETIME2(0) NOT NULL
        CONSTRAINT DF_Recarga_fecha DEFAULT SYSDATETIME(),
    canal NVARCHAR(25) NOT NULL
        CONSTRAINT CK_Recarga_canal CHECK(canal IN(N'Taquilla', N'Máquina de paradero', N'App')),
    referencia NVARCHAR(30) NULL,
    CONSTRAINT CK_Recarga_saldos CHECK(saldo_previo >= 0 AND saldo_posterior >= 0),
    CONSTRAINT CK_Recarga_aritmetica CHECK(saldo_posterior = saldo_previo + monto)
);
GO

CREATE TABLE TransaccionPasaje(
    id_transaccion INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TransaccionPasaje PRIMARY KEY,
    id_tarjeta INT NOT NULL CONSTRAINT FK_Transaccion_Tarjeta REFERENCES Tarjeta(id_tarjeta),
    id_paradero INT NOT NULL CONSTRAINT FK_Transaccion_Paradero REFERENCES Paradero(id_paradero),
    id_regla INT NULL CONSTRAINT FK_Transaccion_Regla REFERENCES ReglaTransbordo(id_regla),
    monto DECIMAL(10,2) NOT NULL CONSTRAINT CK_Transaccion_monto CHECK(monto >= 0),
    tipo_cobro NVARCHAR(10) NOT NULL
        CONSTRAINT CK_Transaccion_tipo CHECK(tipo_cobro IN(N'Directo', N'Transbordo')),
    fecha_hora DATETIME2(0) NOT NULL
        CONSTRAINT DF_Transaccion_fecha DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Transaccion_coherencia
        CHECK((tipo_cobro = N'Directo' AND id_regla IS NULL)
           OR (tipo_cobro = N'Transbordo' AND id_regla IS NOT NULL))
);
GO

PRINT N'=== ARCHIVO 1 COMPLETADO: Base de datos y 11 tablas creadas ===';
GO
