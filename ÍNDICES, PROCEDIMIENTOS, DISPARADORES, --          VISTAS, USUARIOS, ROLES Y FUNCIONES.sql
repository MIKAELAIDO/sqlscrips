-- =========================================================
-- PARTE 2: ÍNDICES, PROCEDIMIENTOS, DISPARADORES,
--          VISTAS, USUARIOS, ROLES Y FUNCIONES
-- =========================================================
USE RUTA_Puebla;
GO

-- =========================================================
-- 1.3 ÍNDICES SECUNDARIOS (17 índices)
-- =========================================================
CREATE INDEX IX_Paradero_id_linea ON Paradero(id_linea);
CREATE INDEX IX_Paradero_id_paradero_enlace ON Paradero(id_paradero_enlace);
CREATE INDEX IX_ReglaTransbordo_origen ON ReglaTransbordo(id_linea_origen);
CREATE INDEX IX_ReglaTransbordo_destino ON ReglaTransbordo(id_linea_destino);
CREATE INDEX IX_Unidad_id_linea_asignada ON Unidad(id_linea_asignada);
CREATE INDEX IX_TurnoTrabajo_id_chofer ON TurnoTrabajo(id_chofer);
CREATE INDEX IX_TurnoTrabajo_id_unidad ON TurnoTrabajo(id_unidad);
CREATE INDEX IX_BitacoraViaje_id_turno ON BitacoraViaje(id_turno);
CREATE INDEX IX_BitacoraViaje_id_unidad ON BitacoraViaje(id_unidad);
CREATE INDEX IX_BitacoraViaje_id_linea ON BitacoraViaje(id_linea);
CREATE INDEX IX_Tarjeta_id_usuario ON Tarjeta(id_usuario);
CREATE INDEX IX_Recarga_id_tarjeta ON Recarga(id_tarjeta);
CREATE INDEX IX_Recarga_fecha_hora ON Recarga(fecha_hora);
CREATE INDEX IX_TransaccionPasaje_id_tarjeta ON TransaccionPasaje(id_tarjeta);
CREATE INDEX IX_TransaccionPasaje_id_paradero ON TransaccionPasaje(id_paradero);
CREATE INDEX IX_TransaccionPasaje_id_regla ON TransaccionPasaje(id_regla);
CREATE INDEX IX_TransaccionPasaje_fecha_hora ON TransaccionPasaje(fecha_hora);
GO

-- =========================================================
-- 1.4 PROCEDIMIENTOS ALMACENADOS (3)
-- =========================================================

-- Procedimiento 1: Recargar tarjeta (del PDF)
CREATE OR ALTER PROCEDURE usp_RecargarTarjeta
    @id_tarjeta INT,
    @monto DECIMAL(10,2),
    @canal NVARCHAR(25),
    @referencia NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @monto IS NULL OR @monto <= 0
        THROW 50010, N'El monto de la recarga debe ser mayor que cero.', 1;

    DECLARE @saldo_previo DECIMAL(10,2),
            @saldo_posterior DECIMAL(10,2),
            @estado NVARCHAR(12),
            @id_recarga INT;

    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @saldo_previo = saldo, @estado = estado
        FROM Tarjeta WITH(UPDLOCK, ROWLOCK)
        WHERE id_tarjeta = @id_tarjeta;

        IF @@ROWCOUNT = 0 THROW 50011, N'La tarjeta indicada no existe.', 1;
        IF @estado <> N'Activa' THROW 50012, N'La tarjeta no está activa; no admite recargas.', 1;

        SET @saldo_posterior = @saldo_previo + @monto;

        INSERT INTO Recarga(id_tarjeta, monto, saldo_previo, saldo_posterior, canal, referencia)
        VALUES(@id_tarjeta, @monto, @saldo_previo, @saldo_posterior, @canal, @referencia);

        SET @id_recarga = SCOPE_IDENTITY();

        UPDATE Tarjeta SET saldo = @saldo_posterior WHERE id_tarjeta = @id_tarjeta;

        COMMIT TRANSACTION;
        SELECT @id_recarga AS id_recarga, @saldo_previo AS saldo_previo, @saldo_posterior AS saldo_posterior;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- Procedimiento 2: Validar pasaje (del PDF)
CREATE OR ALTER PROCEDURE usp_ValidarPasaje
    @id_tarjeta INT,
    @id_paradero INT,
    @id_regla INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @saldo DECIMAL(10,2), @estado NVARCHAR(12),
            @vencimiento DATE, @monto DECIMAL(10,2),
            @tipo_cobro NVARCHAR(10), @hoy DATE = CAST(SYSDATETIME() AS DATE);

    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT @saldo = saldo, @estado = estado, @vencimiento = fecha_vencimiento
        FROM Tarjeta WITH(UPDLOCK, ROWLOCK)
        WHERE id_tarjeta = @id_tarjeta;

        IF @@ROWCOUNT = 0 THROW 50011, N'La tarjeta indicada no existe.', 1;
        IF @estado <> N'Activa' THROW 50012, N'La tarjeta no está activa; no permite el paso.', 1;
        IF @vencimiento IS NOT NULL AND @vencimiento < @hoy
            THROW 50012, N'La tarjeta está vencida; no permite el paso.', 1;

        IF @id_regla IS NULL
        BEGIN
            SET @tipo_cobro = N'Directo';
            SET @monto = 7.50;
        END
        ELSE
        BEGIN
            SET @tipo_cobro = N'Transbordo';
            SELECT @monto = costo FROM ReglaTransbordo
            WHERE id_regla = @id_regla
              AND vigente_desde <= @hoy
              AND (vigente_hasta IS NULL OR vigente_hasta >= @hoy);
            IF @@ROWCOUNT = 0 THROW 50013, N'La regla de transbordo no existe o no está vigente.', 1;
        END

        IF @saldo < @monto THROW 50017, N'Saldo insuficiente para cubrir el pasaje.', 1;

        UPDATE Tarjeta SET saldo = saldo - @monto WHERE id_tarjeta = @id_tarjeta;

        INSERT INTO TransaccionPasaje(id_tarjeta, id_paradero, id_regla, monto, tipo_cobro)
        VALUES(@id_tarjeta, @id_paradero, @id_regla, @monto, @tipo_cobro);

        COMMIT TRANSACTION;
        SELECT SCOPE_IDENTITY() AS id_transaccion, @tipo_cobro AS tipo_cobro,
               @monto AS monto_cobrado, @saldo - @monto AS saldo_restante;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- Procedimiento 3: Asignar turno (NUEVO - CU-03 del reporte)
-- Valida chofer activo, licencia vigente, unidad disponible, y deja que
-- TR_Bitacora_Solape actúe como defensa final contra traslapes.
CREATE OR ALTER PROCEDURE usp_AsignarTurno
    @id_chofer INT,
    @fecha DATE,
    @tipo_turno NVARCHAR(12),
    @hora_inicio TIME(0),
    @hora_fin TIME(0),
    @id_unidad INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @estado_chofer NVARCHAR(12),
            @vigencia_licencia DATE,
            @estado_unidad NVARCHAR(20),
            @id_turno INT;

    BEGIN TRY
        -- Validación del chofer
        SELECT @estado_chofer = estado, @vigencia_licencia = vigencia_licencia
        FROM Chofer WITH(UPDLOCK, ROWLOCK)
        WHERE id_chofer = @id_chofer;

        IF @@ROWCOUNT = 0 THROW 50030, N'El chofer indicado no existe.', 1;
        IF @estado_chofer <> N'Activo'
            THROW 50031, N'El chofer no está activo; no puede asignársele turno.', 1;
        IF @vigencia_licencia < @fecha
            THROW 50032, N'La licencia del chofer está vencida para la fecha del turno.', 1;

        -- Validación de la unidad (si se proporcionó)
        IF @id_unidad IS NOT NULL
        BEGIN
            SELECT @estado_unidad = estado
            FROM Unidad WITH(UPDLOCK, ROWLOCK)
            WHERE id_unidad = @id_unidad;

            IF @@ROWCOUNT = 0 THROW 50033, N'La unidad indicada no existe.', 1;
            IF @estado_unidad NOT IN (N'Disponible', N'En ruta')
                THROW 50034, N'La unidad no está disponible para asignación.', 1;
        END

        -- Inserción del turno. TR_Bitacora_Solape rechazará cualquier traslape.
        INSERT INTO TurnoTrabajo(id_chofer, fecha, tipo_turno, hora_inicio, hora_fin, id_unidad)
        VALUES(@id_chofer, @fecha, @tipo_turno, @hora_inicio, @hora_fin, @id_unidad);

        SET @id_turno = SCOPE_IDENTITY();

        SELECT @id_turno AS id_turno, @id_chofer AS id_chofer, @fecha AS fecha,
               @tipo_turno AS tipo_turno, @hora_inicio AS hora_inicio,
               @hora_fin AS hora_fin, @id_unidad AS id_unidad;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- =========================================================
-- 1.5 DISPARADORES (4 en total)
-- =========================================================

-- Disparador 1: Valida que el tipo_tarifa coincida con el tipo_perfil del usuario
CREATE OR ALTER TRIGGER TR_Tarjeta_Perfil
ON Tarjeta
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(
        SELECT 1 FROM inserted AS i
        JOIN Usuario AS u ON u.id_usuario = i.id_usuario
        WHERE i.tipo_tarifa <> u.tipo_perfil
    )
        THROW 50020, N'El tipo de tarifa debe coincidir con el perfil del usuario.', 1;
END;
GO

-- Disparador 2: Evita traslape de turnos (mismo chofer o misma unidad)
CREATE OR ALTER TRIGGER TR_Bitacora_Solape
ON TurnoTrabajo
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(
        SELECT 1 FROM inserted AS i
        JOIN TurnoTrabajo AS t
          ON t.fecha = i.fecha
         AND t.id_turno <> i.id_turno
         AND (t.id_chofer = i.id_chofer OR t.id_unidad = i.id_unidad)
        WHERE i.hora_inicio < t.hora_fin
          AND t.hora_inicio < i.hora_fin
    )
        THROW 50022, N'El chofer o la unidad ya tiene un turno en ese horario.', 1;
END;
GO

-- Disparador 3: Actualiza automáticamente el saldo de la tarjeta al insertar recarga
CREATE OR ALTER TRIGGER TR_Recarga_ActualizaSaldo
ON Recarga
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Tarjeta
    SET saldo = i.saldo_posterior
    FROM Tarjeta t
    JOIN inserted i ON t.id_tarjeta = i.id_tarjeta;
END;
GO

-- Disparador 4: Descuenta automáticamente el saldo al registrar transacción de pasaje
CREATE OR ALTER TRIGGER TR_Transaccion_DescuentaSaldo
ON TransaccionPasaje
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE Tarjeta
    SET saldo = saldo - i.monto
    FROM Tarjeta t
    JOIN inserted i ON t.id_tarjeta = i.id_tarjeta
    WHERE i.monto > 0;
END;
GO

-- =========================================================
-- 1.6 VISTAS (3 vistas)
-- =========================================================

-- Vista 1: Afluencia y ocupación por línea
CREATE OR ALTER VIEW VW_Afluencia_Linea
AS
SELECT l.id_linea,
       l.nombre AS linea,
       l.color,
       COUNT(b.id_viaje) AS viajes_realizados,
       ISNULL(SUM(b.pasajeros_transportados), 0) AS pasajeros_totales,
       ISNULL(AVG(CAST(b.pasajeros_transportados AS DECIMAL(10,2))), 0) AS pasajeros_promedio
FROM Linea AS l
LEFT JOIN BitacoraViaje AS b ON b.id_linea = l.id_linea
GROUP BY l.id_linea, l.nombre, l.color;
GO

-- Vista 2: Ingresos y validaciones por línea
CREATE OR ALTER VIEW VW_Ingresos_Linea
AS
SELECT l.id_linea,
       l.nombre AS linea,
       COUNT(tp.id_transaccion) AS validaciones,
       ISNULL(SUM(tp.monto), 0) AS ingreso_total,
       ISNULL(SUM(CASE WHEN tp.tipo_cobro = N'Transbordo' THEN 1 ELSE 0 END), 0) AS transbordos
FROM Linea AS l
JOIN Paradero AS p ON p.id_linea = l.id_linea
JOIN TransaccionPasaje AS tp ON tp.id_paradero = p.id_paradero
GROUP BY l.id_linea, l.nombre;
GO

-- Vista 3: Estado consolidado de tarjetas con su historial
CREATE OR ALTER VIEW VW_Estado_Tarjetas
AS
SELECT t.id_tarjeta,
       t.codigo_uid,
       u.nombre + N' ' + u.apellido_paterno AS titular,
       t.tipo_tarifa,
       t.saldo,
       t.estado,
       t.fecha_emision,
       t.fecha_vencimiento,
       ISNULL(r.total_recargas, 0) AS total_recargado,
       ISNULL(p.total_pasajes, 0) AS total_cobrado,
       ISNULL(r.total_recargas, 0) - ISNULL(p.total_pasajes, 0) AS saldo_calculado
FROM Tarjeta AS t
JOIN Usuario AS u ON u.id_usuario = t.id_usuario
LEFT JOIN (SELECT id_tarjeta, SUM(monto) AS total_recargas FROM Recarga GROUP BY id_tarjeta) AS r
    ON r.id_tarjeta = t.id_tarjeta
LEFT JOIN (SELECT id_tarjeta, SUM(monto) AS total_pasajes FROM TransaccionPasaje GROUP BY id_tarjeta) AS p
    ON p.id_tarjeta = t.id_tarjeta;
GO

-- =========================================================
-- 1.7 USUARIOS, LOGINS Y ROLES (3 roles + 3 usuarios)
-- =========================================================

-- Crear roles personalizados
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'rol_taquillero')
    CREATE ROLE rol_taquillero;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'rol_analista')
    CREATE ROLE rol_analista;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'rol_coordinador')
    CREATE ROLE rol_coordinador;
GO

-- Permisos al rol taquillero
GRANT EXECUTE ON usp_RecargarTarjeta TO rol_taquillero;
GRANT EXECUTE ON usp_ValidarPasaje TO rol_taquillero;
GRANT SELECT ON Tarjeta TO rol_taquillero;
GRANT INSERT ON Recarga TO rol_taquillero;
GRANT INSERT ON TransaccionPasaje TO rol_taquillero;
GO

-- Permisos al rol analista
GRANT SELECT ON VW_Afluencia_Linea TO rol_analista;
GRANT SELECT ON VW_Ingresos_Linea TO rol_analista;
GRANT SELECT ON VW_Estado_Tarjetas TO rol_analista;
GRANT SELECT ON Linea TO rol_analista;
GRANT SELECT ON Paradero TO rol_analista;
GRANT SELECT ON BitacoraViaje TO rol_analista;
GRANT SELECT ON TransaccionPasaje TO rol_analista;
GO

-- Permisos al rol coordinador (incluye el nuevo procedimiento)
GRANT EXECUTE ON usp_AsignarTurno TO rol_coordinador;
GRANT SELECT, INSERT, UPDATE ON TurnoTrabajo TO rol_coordinador;
GRANT SELECT, INSERT, UPDATE ON BitacoraViaje TO rol_coordinador;
GRANT SELECT, INSERT, UPDATE ON Chofer TO rol_coordinador;
GRANT SELECT, INSERT, UPDATE ON Unidad TO rol_coordinador;
GO

-- Crear logins a nivel de servidor
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'login_taquillero')
    CREATE LOGIN login_taquillero WITH PASSWORD = N'Taquilla2026!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'login_analista')
    CREATE LOGIN login_analista WITH PASSWORD = N'Analista2026!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'login_coordinador')
    CREATE LOGIN login_coordinador WITH PASSWORD = N'Coordinador2026!', CHECK_POLICY = OFF;
GO

-- Crear usuarios en la base de datos
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_taquillero')
    CREATE USER user_taquillero FOR LOGIN login_taquillero;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_analista')
    CREATE USER user_analista FOR LOGIN login_analista;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'user_coordinador')
    CREATE USER user_coordinador FOR LOGIN login_coordinador;
GO

-- Asignar usuarios a sus roles
ALTER ROLE rol_taquillero ADD MEMBER user_taquillero;
ALTER ROLE rol_analista ADD MEMBER user_analista;
ALTER ROLE rol_coordinador ADD MEMBER user_coordinador;
GO

PRINT N'=== PARTE 1 COMPLETADA ===';
GO

-- =========================================================
-- 1.8 FUNCIONES DEFINIDAS POR EL USUARIO (3 funciones)
-- =========================================================

-- Función 1: Calcular el saldo real de una tarjeta basado en su historial
CREATE OR ALTER FUNCTION fn_CalcularSaldoTarjeta(@id_tarjeta INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @recargas DECIMAL(10,2), @pasajes DECIMAL(10,2);
    SELECT @recargas = ISNULL(SUM(monto), 0) FROM Recarga WHERE id_tarjeta = @id_tarjeta;
    SELECT @pasajes = ISNULL(SUM(monto), 0) FROM TransaccionPasaje WHERE id_tarjeta = @id_tarjeta;
    RETURN @recargas - @pasajes;
END;
GO

-- Función 2: Calcular días restantes para el vencimiento de la licencia de un chofer
CREATE OR ALTER FUNCTION fn_DiasVencimientoLicencia(@id_chofer INT)
RETURNS INT
AS
BEGIN
    DECLARE @dias INT;
    SELECT @dias = DATEDIFF(DAY, CAST(GETDATE() AS DATE), vigencia_licencia)
    FROM Chofer
    WHERE id_chofer = @id_chofer;
    RETURN @dias;
END;
GO

-- Función 3: Total de pasajeros transportados en una línea en un periodo
CREATE OR ALTER FUNCTION fn_TotalPasajerosLinea(@id_linea INT, @desde DATE, @hasta DATE)
RETURNS INT
AS
BEGIN
    DECLARE @total INT;
    SELECT @total = ISNULL(SUM(pasajeros_transportados), 0)
    FROM BitacoraViaje
    WHERE id_linea = @id_linea
      AND CAST(hora_salida AS DATE) BETWEEN @desde AND @hasta;
    RETURN @total;
END;
GO
