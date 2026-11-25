-- =========================================================
-- PARTE 2: INSERCIÓN DE DATOS (POBLADO)
-- =========================================================
USE RUTA_Puebla;
GO

-- 2.1 INFRAESTRUCTURA (Líneas, Paraderos, Reglas de Transbordo)
SET IDENTITY_INSERT Linea ON;
INSERT INTO Linea(id_linea, nombre, color, longitud_km, recorrido, estado) VALUES
(1, N'L1 Tlaxcalancingo-Chachapa', N'Azul', 28.40, N'Centro-Angelópolis-Tlaxcalancingo', N'Activa'),
(2, N'L2 Margaritas-Diagonal', N'Verde', 24.10, N'Margaritas-CAPU-Diagonal', N'Activa'),
(3, N'L3 Valsequillo-CAPU', N'Naranja', 31.70, N'Valsequillo-Centro-CAPU', N'Activa'),
(4, N'L4 Periférico Ecológico', N'Morado', 38.90, N'Periférico Ecológico-Amalucan', N'Activa');
SET IDENTITY_INSERT Linea OFF;
GO

SET IDENTITY_INSERT Paradero ON;
INSERT INTO Paradero(id_paradero, id_linea, nombre, orden, latitud, longitud, tipo, id_paradero_enlace) VALUES
(1, 1, N'Tlaxcalancingo', 1, 19.026400, -98.244800, N'Terminal', NULL),
(2, 1, N'Angelópolis', 2, 19.031500, -98.247100, N'Troncal', NULL),
(3, 1, N'Capu', 3, 19.069800, -98.244700, N'Troncal', 8),
(4, 2, N'Margaritas', 1, 19.083600, -98.279900, N'Terminal', NULL),
(5, 2, N'Diagonal', 2, 19.035200, -98.234500, N'Troncal', NULL),
(6, 2, N'Capu', 3, 19.070100, -98.245200, N'Troncal', 3),
(7, 3, N'Valsequillo', 1, 18.966700, -98.187600, N'Terminal', NULL),
(8, 3, N'Capu', 2, 19.069900, -98.244900, N'Troncal', 3),
(9, 4, N'Periférico Ecológico', 1, 19.021400, -98.183700, N'Terminal', NULL),
(10, 4, N'Amalucan', 2, 19.042300, -98.155100, N'Terminal', NULL);
SET IDENTITY_INSERT Paradero OFF;
GO

SET IDENTITY_INSERT ReglaTransbordo ON;
INSERT INTO ReglaTransbordo(id_regla, id_linea_origen, id_linea_destino, costo, vigente_desde, vigente_hasta) VALUES
(1, 1, 2, 0.00, '2026-01-01', NULL),
(2, 2, 1, 0.00, '2026-01-01', NULL),
(3, 1, 3, 0.00, '2026-01-01', NULL),
(4, 3, 1, 0.00, '2026-01-01', NULL),
(5, 2, 3, 0.00, '2026-01-01', NULL),
(6, 3, 2, 0.00, '2026-01-01', NULL),
(7, 3, 4, 7.50, '2026-01-01', NULL),
(8, 4, 3, 7.50, '2026-01-01', NULL),
(9, 1, 4, 7.50, '2026-01-01', NULL),
(10, 4, 1, 7.50, '2026-01-01', NULL),
(11, 2, 4, 7.50, '2026-01-01', NULL),
(12, 4, 2, 7.50, '2026-01-01', NULL);
SET IDENTITY_INSERT ReglaTransbordo OFF;
GO

-- 2.2 FLOTA Y OPERACIÓN
SET IDENTITY_INSERT Unidad ON;
INSERT INTO Unidad(id_unidad, numero_economico, placas, capacidad, modelo, anio, estado, id_linea_asignada) VALUES
(1, N'UT-101', N'PUE-101-A', 160, N'Volvo 7900 Articulado', 2022, N'Disponible', 1),
(2, N'UT-102', N'PUE-102-A', 160, N'Volvo 7900 Articulado', 2022, N'En ruta', 2),
(3, N'UT-103', N'PUE-103-A', 140, N'Mercedes-Benz Citaro', 2021, N'En ruta', 3),
(4, N'UT-104', N'PUE-104-A', 140, N'Mercedes-Benz Citaro', 2023, N'Mantenimiento', 4);
SET IDENTITY_INSERT Unidad OFF;
GO

SET IDENTITY_INSERT Chofer ON;
INSERT INTO Chofer(id_chofer, nombre, apellido_paterno, apellido_materno, num_licencia, tipo_licencia, vigencia_licencia, telefono, estado) VALUES
(1, N'Ricardo', N'Morales', N'Cano', N'PUE-884231', N'C', '2028-03-15', N'2221234567', N'Activo'),
(2, N'Lucía', N'Ramírez', N'Ortiz', N'PUE-884232', N'C', '2027-11-30', N'2221234568', N'Activo'),
(3, N'Andrés', N'Fuentes', N'Lara', N'PUE-884233', N'B', '2026-12-01', N'2221234569', N'Activo'),
(4, N'Verónica', N'Sánchez', N'Pineda', N'PUE-884234', N'C', '2029-05-20', N'2221234570', N'Activo');
SET IDENTITY_INSERT Chofer OFF;
GO

SET IDENTITY_INSERT TurnoTrabajo ON;
INSERT INTO TurnoTrabajo(id_turno, id_chofer, fecha, tipo_turno, hora_inicio, hora_fin, id_unidad) VALUES
(1, 1, '2026-11-17', N'Matutino', '05:00:00', '13:00:00', 1),
(2, 2, '2026-11-17', N'Matutino', '05:00:00', '13:00:00', 2),
(3, 3, '2026-11-17', N'Vespertino', '13:00:00', '21:00:00', 3),
(4, 4, '2026-11-17', N'Nocturno', '21:00:00', '05:00:00', 4);
SET IDENTITY_INSERT TurnoTrabajo OFF;
GO

SET IDENTITY_INSERT BitacoraViaje ON;
INSERT INTO BitacoraViaje(id_viaje, id_turno, id_unidad, id_linea, hora_salida, hora_llegada, pasajeros_transportados, observaciones) VALUES
(1, 1, 1, 1, '2026-11-17T06:10:00', '2026-11-17T07:25:00', 118, N'Recorrido sin incidentes'),
(2, 2, 2, 2, '2026-11-17T06:15:00', '2026-11-17T07:20:00', 96, N'Tráfico moderado en Diagonal'),
(3, 3, 3, 3, '2026-11-17T13:20:00', '2026-11-17T14:35:00', 104, N'Retraso de 8 minutos por obra'),
(4, 4, 4, 4, '2026-11-17T21:30:00', '2026-11-17T22:50:00', 62, NULL);
SET IDENTITY_INSERT BitacoraViaje OFF;
GO

-- 2.3 PREPAGO Y ACCESOS
SET IDENTITY_INSERT Usuario ON;
INSERT INTO Usuario(id_usuario, nombre, apellido_paterno, apellido_materno, correo, telefono, tipo_perfil, fecha_registro) VALUES
(1, N'María', N'López', N'Hernández', N'maria.lopez@example.com', N'2221110001', N'General', '2026-02-04T09:00:00'),
(2, N'Diego', N'Castro', N'Reyes', N'diego.castro@example.com', N'2221110002', N'Estudiante', '2026-03-11T11:30:00'),
(3, N'Rosa', N'Vega', N'Miranda', NULL, N'2221110003', N'Adulto mayor', '2026-04-02T16:45:00');
SET IDENTITY_INSERT Usuario OFF;
GO

SET IDENTITY_INSERT Tarjeta ON;
INSERT INTO Tarjeta(id_tarjeta, id_usuario, codigo_uid, tipo_tarifa, saldo, estado, fecha_emision, fecha_vencimiento) VALUES
(1, 1, N'A1B2C3D4E5F60001', N'General', 0.00, N'Activa', '2026-02-04', '2028-02-04'),
(2, 1, N'A1B2C3D4E5F60002', N'General', 0.00, N'Activa', '2026-05-19', '2028-05-19'),
(3, 2, N'A1B2C3D4E5F60003', N'Estudiante', 0.00, N'Activa', '2026-03-11', '2028-03-11'),
(4, 2, N'A1B2C3D4E5F60004', N'Estudiante', 0.00, N'Activa', '2026-08-23', '2028-08-23'),
(5, 3, N'A1B2C3D4E5F60005', N'Adulto mayor', 0.00, N'Activa', '2026-04-02', '2028-04-02'),
(6, 3, N'A1B2C3D4E5F60006', N'Adulto mayor', 0.00, N'Activa', '2026-09-14', '2028-09-14');
SET IDENTITY_INSERT Tarjeta OFF;
GO

-- Nota: los disparadores TR_Recarga_ActualizaSaldo y TR_Transaccion_DescuentaSaldo
-- actualizan automáticamente el saldo de la tarjeta, por lo que se inserta con saldo 0.
SET IDENTITY_INSERT Recarga ON;
INSERT INTO Recarga(id_recarga, id_tarjeta, monto, saldo_previo, saldo_posterior, fecha_hora, canal, referencia) VALUES
(1, 1, 50.00, 0.00, 50.00, '2026-11-16T08:15:00', N'Taquilla', N'TAQ-0001'),
(2, 2, 30.00, 0.00, 30.00, '2026-11-16T08:40:00', N'Máquina de paradero', N'MAQ-0002'),
(3, 3, 40.00, 0.00, 40.00, '2026-11-16T09:05:00', N'App', N'APP-0003'),
(4, 4, 20.00, 0.00, 20.00, '2026-11-16T18:20:00', N'Taquilla', N'TAQ-0004'),
(5, 5, 30.00, 0.00, 30.00, '2026-11-17T07:10:00', N'Máquina de paradero', N'MAQ-0005'),
(6, 6, 15.00, 0.00, 15.00, '2026-11-17T07:45:00', N'App', N'APP-0006');
SET IDENTITY_INSERT Recarga OFF;
GO

SET IDENTITY_INSERT TransaccionPasaje ON;
INSERT INTO TransaccionPasaje(id_transaccion, id_tarjeta, id_paradero, id_regla, monto, tipo_cobro, fecha_hora) VALUES
(1, 1, 2, NULL, 7.50, N'Directo', '2026-11-17T06:20:00'),
(2, 1, 5, 1, 0.00, N'Transbordo', '2026-11-17T06:55:00'),
(3, 2, 4, NULL, 7.50, N'Directo', '2026-11-17T06:25:00'),
(4, 3, 7, NULL, 7.50, N'Directo', '2026-11-17T07:00:00'),
(5, 3, 10, 7, 7.50, N'Transbordo', '2026-11-17T07:40:00'),
(6, 4, 6, NULL, 7.50, N'Directo', '2026-11-17T08:10:00'),
(7, 5, 1, NULL, 7.50, N'Directo', '2026-11-17T08:30:00'),
(8, 6, 9, NULL, 7.50, N'Directo', '2026-11-17T09:00:00'),
(9, 6, 7, 8, 7.50, N'Transbordo', '2026-11-17T09:35:00');
SET IDENTITY_INSERT TransaccionPasaje OFF;
GO

PRINT N'=== PARTE 2 COMPLETADA ===';
GO
