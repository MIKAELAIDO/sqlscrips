
USE RUTA_Puebla;
GO

-- =========================================================
-- 3.1 CONSULTAS DE VERIFICACIÓN (7 consultas del documento)
-- =========================================================

-- Consulta 1: Afluencia por línea (revision de que no jala)
SELECT l.nombre AS linea,
       COUNT(b.id_viaje) AS viajes,
       SUM(b.pasajeros_transportados) AS pasajeros
FROM Linea AS l
LEFT JOIN BitacoraViaje AS b ON b.id_linea = l.id_linea
GROUP BY l.nombre
ORDER BY l.id_linea;
GO

-- Consulta 2: Ingresos por línea
SELECT l.nombre AS linea,
       COUNT(*) AS validaciones,
       SUM(tp.monto) AS ingreso
FROM TransaccionPasaje AS tp
JOIN Paradero AS p ON p.id_paradero = tp.id_paradero
JOIN Linea AS l ON l.id_linea = p.id_linea
GROUP BY l.id_linea, l.nombre
ORDER BY l.id_linea;
GO

-- Consulta 3: Transbordos aplicados
SELECT ro.nombre AS origen,
       rd.nombre AS destino,
       rt.costo,
       COUNT(*) AS aplicaciones
FROM TransaccionPasaje AS tp
JOIN ReglaTransbordo AS rt ON rt.id_regla = tp.id_regla
JOIN Linea AS ro ON ro.id_linea = rt.id_linea_origen
JOIN Linea AS rd ON rd.id_linea = rt.id_linea_destino
GROUP BY ro.nombre, rd.nombre, rt.costo
ORDER BY aplicaciones DESC, ro.nombre, rd.nombre;
GO

-- Consulta 4: Consistencia de saldos (debe devolver 0 filas)
SELECT t.id_tarjeta,
       t.saldo,
       ISNULL(r.total_recargas, 0) - ISNULL(p.total_pasajes, 0) AS saldo_calculado
FROM Tarjeta AS t
LEFT JOIN (SELECT id_tarjeta, SUM(monto) AS total_recargas FROM Recarga GROUP BY id_tarjeta) AS r
    ON r.id_tarjeta = t.id_tarjeta
LEFT JOIN (SELECT id_tarjeta, SUM(monto) AS total_pasajes FROM TransaccionPasaje GROUP BY id_tarjeta) AS p
    ON p.id_tarjeta = t.id_tarjeta
WHERE t.saldo <> ISNULL(r.total_recargas, 0) - ISNULL(p.total_pasajes, 0);
GO

-- Consulta 5: Ocupación por turno
SELECT c.nombre + N' ' + c.apellido_paterno AS chofer,
       tt.tipo_turno,
       tt.hora_inicio,
       tt.hora_fin,
       u.numero_economico,
       SUM(b.pasajeros_transportados) AS pasajeros
FROM TurnoTrabajo AS tt
JOIN Chofer AS c ON c.id_chofer = tt.id_chofer
LEFT JOIN Unidad AS u ON u.id_unidad = tt.id_unidad
LEFT JOIN BitacoraViaje AS b ON b.id_turno = tt.id_turno
GROUP BY c.nombre, c.apellido_paterno, tt.tipo_turno, tt.hora_inicio, tt.hora_fin, u.numero_economico
ORDER BY tt.hora_inicio;
GO

-- Consulta 6: Usando las vistas creadas
SELECT * FROM VW_Afluencia_Linea;
SELECT * FROM VW_Ingresos_Linea;
SELECT * FROM VW_Estado_Tarjetas;
GO

-- =========================================================
-- 3.2 PRUEBAS DE RECHAZO (deben fallar con el error esperado)
-- =========================================================

-- Prueba 1: Tarjeta con tarifa distinta al perfil (Error 50020)
BEGIN TRY
    INSERT INTO Tarjeta(id_usuario, codigo_uid, tipo_tarifa, saldo, estado)
    VALUES(1, N'A1B2C3D4E5F60099', N'Estudiante', 0.00, N'Activa');
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

-- Prueba 2: Turno que se solapa con otro (Error 50022)
BEGIN TRY
    INSERT INTO TurnoTrabajo(id_chofer, fecha, tipo_turno, hora_inicio, hora_fin, id_unidad)
    VALUES(1, '2026-11-17', N'Vespertino', '10:00:00', '18:00:00', 1);
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

-- Prueba 3: Recarga con monto no positivo (Error 50010)
BEGIN TRY
    EXEC usp_RecargarTarjeta @id_tarjeta = 1, @monto = 0.00, @canal = N'Taquilla';
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

-- Prueba 4: Pasaje sin saldo suficiente (Error 50017)
BEGIN TRY
    EXEC usp_ValidarPasaje @id_tarjeta = 6, @id_paradero = 1;
END TRY
BEGIN CATCH
    SELECT ERROR_NUMBER() AS error, ERROR_MESSAGE() AS mensaje;
END CATCH;
GO

-- =========================================================
-- 3.3 UPDATES DE EJEMPLO
-- =========================================================

-- Update 1: Cambiar estado de una unidad a mantenimiento
UPDATE Unidad SET estado = N'Mantenimiento' WHERE id_unidad = 1;

-- Update 2: Actualizar teléfono de un chofer
UPDATE Chofer SET telefono = N'2229998877' WHERE id_chofer = 1;

-- Update 3: Cambiar el estado de una tarjeta a bloqueada
UPDATE Tarjeta SET estado = N'Bloqueada' WHERE id_tarjeta = 4;

-- Update 4: Actualizar la longitud de una línea
UPDATE Linea SET longitud_km = 29.50 WHERE id_linea = 1;
GO

-- =========================================================
-- 3.4 DELETES DE EJEMPLO
-- =========================================================

-- Delete 1: Eliminar observaciones de un viaje (poner en NULL)
UPDATE BitacoraViaje SET observaciones = NULL WHERE id_viaje = 2;

-- Delete 2: Dar de baja una tarjeta (cambiar estado, no borrar por integridad referencial)
UPDATE Tarjeta SET estado = N'Baja' WHERE id_tarjeta = 2;

-- Delete 3: Eliminar un registro de recarga (solo si no hay dependencias)
DELETE FROM Recarga WHERE id_recarga = 6;

-- Delete 4: Eliminar una regla de transbordo (solo si no se ha usado)
DELETE FROM ReglaTransbordo WHERE id_regla = 12;
GO

-- Delete 5: Eliminar un turno sin viajes asociados
DELETE FROM TurnoTrabajo WHERE id_turno = 4;

-- =========================================================
-- 3.5 JOBS DEL SQL SERVER AGENT (3 Jobs)
-- =========================================================

-- Job 1: Bloquear tarjetas vencidas diariamente
USE msdb;
GO

EXEC sp_add_job
    @job_name = N'RUTA_Bloquear_Tarjetas_Vencidas',
    @description = N'Bloquea automáticamente las tarjetas cuya fecha de vencimiento sea menor a la fecha actual.',
    @enabled = 1;
GO

EXEC sp_add_jobstep
    @job_name = N'RUTA_Bloquear_Tarjetas_Vencidas',
    @step_name = N'Bloquear vencidas',
    @subsystem = N'TSQL',
    @command = N'
        USE RUTA_Puebla;
        UPDATE Tarjeta
        SET estado = N''Vencida''
        WHERE estado = N''Activa''
          AND fecha_vencimiento IS NOT NULL
          AND fecha_vencimiento < CAST(SYSDATETIME() AS DATE);',
    @database_name = N'RUTA_Puebla';
GO

EXEC sp_add_schedule
    @schedule_name = N'Diario_02AM',
    @freq_type = 4,        -- Diario
    @freq_interval = 1,
    @active_start_time = 020000;  -- 2:00 AM
GO

EXEC sp_attach_schedule
    @job_name = N'RUTA_Bloquear_Tarjetas_Vencidas',
    @schedule_name = N'Diario_02AM';
GO

EXEC sp_add_jobserver
    @job_name = N'RUTA_Bloquear_Tarjetas_Vencidas';
GO

-- Job 2: Respaldo diario de la base de datos
EXEC sp_add_job
    @job_name = N'RUTA_Respaldo_Diario',
    @description = N'Respaldo completo diario de la base RUTA_Puebla.',
    @enabled = 1;
GO

EXEC sp_add_jobstep
    @job_name = N'RUTA_Respaldo_Diario',
    @step_name = N'Backup completo',
    @subsystem = N'TSQL',
    @command = N'
        DECLARE @ruta NVARCHAR(256);
        SET @ruta = N''C:\Backups\RUTA_Puebla_'' + CONVERT(NVARCHAR(8), GETDATE(), 112) + N''.bak'';
        BACKUP DATABASE RUTA_Puebla TO DISK = @ruta WITH INIT, COMPRESSION;';
GO

EXEC sp_add_schedule
    @schedule_name = N'Diario_23PM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 230000;  -- 11:00 PM
GO

EXEC sp_attach_schedule
    @job_name = N'RUTA_Respaldo_Diario',
    @schedule_name = N'Diario_23PM';
GO

EXEC sp_add_jobserver
    @job_name = N'RUTA_Respaldo_Diario';
GO

-- Job 3: Limpieza mensual de bitácora antigua (más de 1 año)
EXEC sp_add_job
    @job_name = N'RUTA_Limpieza_Bitacora_Antigua',
    @description = N'Elimina viajes con más de 1 año de antigüedad.',
    @enabled = 1;
GO

EXEC sp_add_jobstep
    @job_name = N'RUTA_Limpieza_Bitacora_Antigua',
    @step_name = N'Borrar bitácora vieja',
    @subsystem = N'TSQL',
    @command = N'
        USE RUTA_Puebla;
        DELETE FROM BitacoraViaje
        WHERE hora_salida < DATEADD(YEAR, -1, GETDATE());',
    @database_name = N'RUTA_Puebla';
GO

EXEC sp_add_schedule
    @schedule_name = N'Mensual_Dia1',
    @freq_type = 16,       -- Mensual
    @freq_interval = 1,
    @freq_recurrence_factor = 1,
    @active_start_time = 030000;  -- 3:00 AM
GO

EXEC sp_attach_schedule
    @job_name = N'RUTA_Limpieza_Bitacora_Antigua',
    @schedule_name = N'Mensual_Dia1';
GO

EXEC sp_add_jobserver
    @job_name = N'RUTA_Limpieza_Bitacora_Antigua';
GO

PRINT N'=== PARTE 3 COMPLETADA ===';
GO

-- =========================================================
-- 3.6 JOBS DE NOTIFICACIONES 
-- =========================================================

-- NOTA: Estos Jobs requieren que Database Mail esté configurado en el servidor.
-- Para configurar: Management -> Database Mail -> Configure Database Mail
-- Perfil requerido: 'PerfilRUTA'

-- Job 4: Notificar licencias de choferes por vencer (30 días)
EXEC sp_add_job
    @job_name = N'RUTA_Notificar_Licencias_Por_Vencer',
    @description = N'Envía un correo al coordinador con las licencias de choferes que vencen en los próximos 30 días.',
    @enabled = 1;
GO

EXEC sp_add_jobstep
    @job_name = N'RUTA_Notificar_Licencias_Por_Vencer',
    @step_name = N'Enviar correo de licencias',
    @subsystem = N'TSQL',
    @command = N'
        USE RUTA_Puebla;
        DECLARE @cuerpo NVARCHAR(MAX) = N''<h3>Licencias por vencer en los próximos 30 días</h3><table border="1"><tr><th>Chofer</th><th>Licencia</th><th>Vence</th><th>Días</th></tr>'';
        SELECT @cuerpo = @cuerpo + ''<tr><td>'' + nombre + '' '' + apellido_paterno + ''</td><td>'' + num_licencia + ''</td><td>'' + CONVERT(NVARCHAR, vigencia_licencia, 103) + ''</td><td>'' + CAST(DATEDIFF(DAY, CAST(GETDATE() AS DATE), vigencia_licencia) AS NVARCHAR) + ''</td></tr>''
        FROM Chofer
        WHERE estado = N''Activo''
          AND vigencia_licencia BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 30, CAST(GETDATE() AS DATE));
        SET @cuerpo = @cuerpo + ''</table>'';

        IF EXISTS(SELECT 1 FROM Chofer WHERE estado = N''Activo'' AND vigencia_licencia BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 30, CAST(GETDATE() AS DATE)))
        BEGIN
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = N''PerfilRUTA'',
                @recipients = N''coordinador@ruta-puebla.com'',
                @subject = N''[RUTA] Alerta: Licencias de choferes por vencer'',
                @body = @cuerpo,
                @body_format = ''HTML'';
        END',
    @database_name = N'RUTA_Puebla';
GO

EXEC sp_add_schedule
    @schedule_name = N'Diario_08AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 080000;
GO

EXEC sp_attach_schedule
    @job_name = N'RUTA_Notificar_Licencias_Por_Vencer',
    @schedule_name = N'Diario_08AM';
GO

EXEC sp_add_jobserver
    @job_name = N'RUTA_Notificar_Licencias_Por_Vencer';
GO

-- Job 5: Notificar tarjetas de prepago por vencer (15 días)
EXEC sp_add_job
    @job_name = N'RUTA_Notificar_Tarjetas_Por_Vencer',
    @description = N'Envía un correo al taquillero con las tarjetas que vencen en los próximos 15 días.',
    @enabled = 1;
GO

EXEC sp_add_jobstep
    @job_name = N'RUTA_Notificar_Tarjetas_Por_Vencer',
    @step_name = N'Enviar correo de tarjetas',
    @subsystem = N'TSQL',
    @command = N'
        USE RUTA_Puebla;
        DECLARE @cuerpo NVARCHAR(MAX) = N''<h3>Tarjetas por vencer en los próximos 15 días</h3><table border="1"><tr><th>UID</th><th>Titular</th><th>Vence</th><th>Días</th></tr>'';
        SELECT @cuerpo = @cuerpo + ''<tr><td>'' + t.codigo_uid + ''</td><td>'' + u.nombre + '' '' + u.apellido_paterno + ''</td><td>'' + CONVERT(NVARCHAR, t.fecha_vencimiento, 103) + ''</td><td>'' + CAST(DATEDIFF(DAY, CAST(GETDATE() AS DATE), t.fecha_vencimiento) AS NVARCHAR) + ''</td></tr>''
        FROM Tarjeta t
        JOIN Usuario u ON u.id_usuario = t.id_usuario
        WHERE t.estado = N''Activa''
          AND t.fecha_vencimiento IS NOT NULL
          AND t.fecha_vencimiento BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 15, CAST(GETDATE() AS DATE));
        SET @cuerpo = @cuerpo + ''</table>'';

        IF EXISTS(SELECT 1 FROM Tarjeta WHERE estado = N''Activa'' AND fecha_vencimiento IS NOT NULL AND fecha_vencimiento BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 15, CAST(GETDATE() AS DATE)))
        BEGIN
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = N''PerfilRUTA'',
                @recipients = N''taquilla@ruta-puebla.com'',
                @subject = N''[RUTA] Alerta: Tarjetas de prepago por vencer'',
                @body = @cuerpo,
                @body_format = ''HTML'';
        END',
    @database_name = N'RUTA_Puebla';
GO

EXEC sp_add_schedule
    @schedule_name = N'Diario_09AM',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 090000;
GO

EXEC sp_attach_schedule
    @job_name = N'RUTA_Notificar_Tarjetas_Por_Vencer',
    @schedule_name = N'Diario_09AM';
GO

EXEC sp_add_jobserver
    @job_name = N'RUTA_Notificar_Tarjetas_Por_Vencer';
GO

-- =========================================================
-- 3.7 USO DE FUNCIONES (ejemplos)
-- =========================================================

-- Ejemplo 1: Verificar saldo real de todas las tarjetas
SELECT id_tarjeta, 
       saldo AS saldo_actual,
       dbo.fn_CalcularSaldoTarjeta(id_tarjeta) AS saldo_calculado
FROM Tarjeta;
GO

-- Ejemplo 2: Choferes con licencia por vencer en menos de 90 días
SELECT nombre + ' ' + apellido_paterno AS chofer,
       vigencia_licencia,
       dbo.fn_DiasVencimientoLicencia(id_chofer) AS dias_restantes
FROM Chofer
WHERE dbo.fn_DiasVencimientoLicencia(id_chofer) < 90
ORDER BY dias_restantes;
GO

-- Ejemplo 3: Pasajeros transportados en noviembre 2026 por línea
SELECT l.nombre AS linea,
       dbo.fn_TotalPasajerosLinea(l.id_linea, '2026-11-01', '2026-11-30') AS pasajeros_noviembre
FROM Linea l;
GO

-- =========================================================
-- 3.8 RESPALDO MANUAL DE LA BASE DE DATOS
-- =========================================================
BACKUP DATABASE RUTA_Puebla 
TO DISK = N'C:\Backups\RUTA_Puebla_RespaldoManual.bak'
WITH INIT, COMPRESSION, STATS = 10;
GO

-- =========================================================
-- VERIFICACIÓN FINAL
-- =========================================================
USE RUTA_Puebla;
SELECT COUNT(*) AS tablas FROM sys.tables
WHERE name IN('Linea','Paradero','ReglaTransbordo','Unidad','Chofer',
              'TurnoTrabajo','BitacoraViaje','Usuario','Tarjeta','Recarga','TransaccionPasaje');
SELECT SUM(pasajeros_transportados) AS pasajeros_totales FROM BitacoraViaje;
SELECT COUNT(*) AS disparadores FROM sys.triggers WHERE parent_id > 0;
SELECT COUNT(*) AS vistas FROM sys.views WHERE name LIKE 'VW_%';
SELECT COUNT(*) AS jobs FROM msdb.dbo.sysjobs WHERE name LIKE 'RUTA_%';
GO
