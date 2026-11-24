-- =========================================================
-- PARTE 5: JOBS DEL SQL SERVER AGENT Y RESPALDOS
-- =========================================================

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
-- 3.8 RESPALDO MANUAL DE LA BASE DE DATOS
-- =========================================================
BACKUP DATABASE RUTA_Puebla 
TO DISK = N'C:\Backups\RUTA_Puebla_RespaldoManual.bak'
WITH INIT, COMPRESSION, STATS = 10;
GO

-- =========================================================
-- VERIFICACIÓN DE JOBS REGISTRADOS
-- =========================================================
SELECT COUNT(*) AS jobs FROM msdb.dbo.sysjobs WHERE name LIKE 'RUTA_%';
GO
