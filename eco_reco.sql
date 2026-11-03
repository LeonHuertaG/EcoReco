-- ----------------------------- CREACIÓN DE DB ----------------------------------------

DROP DATABASE IF EXISTS eco_reco;
CREATE DATABASE eco_reco;
USE eco_reco;

CREATE TABLE usuarios(
    pk_usuario INT PRIMARY KEY AUTO_INCREMENT,
    fk_rol INT,
    usuario VARCHAR(120),
    nombre VARCHAR(255),
    correo VARCHAR(120),
    pass VARCHAR(255),
    fecha_creacion DATETIME,
    estado INT DEFAULT 1
);

CREATE TABLE roles(
    pk_rol INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(120),
    descripcion VARCHAR(255),
    estado INT DEFAULT 1
);

CREATE TABLE clientes(
    pk_cliente INT PRIMARY KEY AUTO_INCREMENT,
    fk_usuario INT,
    nombre VARCHAR(120),
    telefono VARCHAR(10),
    correo VARCHAR(120),
    fk_actividad_comercial INT,
    razon_social VARCHAR(255),
    rfc VARCHAR(13),
    direccion VARCHAR(255),
    fk_colonia INT,
    codigo_postal VARCHAR(10),
    fecha_registro DATETIME,
    estado INT DEFAULT 1
);

CREATE TABLE actividades_comerciales(
    pk_actividad_comercial INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(120),
    descripcion VARCHAR(255),
    estado INT DEFAULT 1
);

CREATE TABLE sectores(
    pk_sector INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(120),
    descripcion VARCHAR(255),
    estado INT DEFAULT 1
);

CREATE TABLE contratos(
    pk_contrato INT PRIMARY KEY AUTO_INCREMENT,
    fk_cliente INT,
    folio VARCHAR(50),
    fecha_inicio DATE,
    fecha_fin DATE,
    descripcion VARCHAR(255),
    monto DECIMAL(10,2),
    frecuencia_recoleccion VARCHAR(120),
    fecha_creacion DATETIME,
    estado INT DEFAULT 1
);

CREATE TABLE recolecciones(
    pk_recoleccion INT PRIMARY KEY AUTO_INCREMENT,
    fk_cliente INT,
    fk_contrato INT,
    fk_ruta INT,
    fk_chofer INT,
    fk_turno INT,
    folio VARCHAR(50),
    fecha_recoleccion DATETIME,
    observaciones VARCHAR(255),
    total DECIMAL(10,2),
    estado INT DEFAULT 1
);

CREATE TABLE recolecciones_detalle(
    pk_recoleccion_detalle INT PRIMARY KEY AUTO_INCREMENT,
    fk_recoleccion INT,
    fk_desecho INT,
    cantidad DECIMAL(10,2),
    peso DECIMAL(10,2),
    precio_unitario DECIMAL(10,2),
    subtotal DECIMAL(10,2),
    observaciones VARCHAR(255),
    estado INT DEFAULT 1
);

CREATE TABLE desechos(
    pk_desecho INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(120),
    descripcion VARCHAR(255),
    tipo VARCHAR(120),
    unidad_medida VARCHAR(50),
    precio DECIMAL(10,2),
    estado INT DEFAULT 1
);

CREATE TABLE rutas(
    pk_ruta INT PRIMARY KEY AUTO_INCREMENT,
    fk_sector INT,
    nombre VARCHAR(120),
    descripcion VARCHAR(255),
    fecha_creacion DATETIME,
    estado INT DEFAULT 1
);

CREATE TABLE choferes(
    pk_chofer INT PRIMARY KEY AUTO_INCREMENT,
    fk_usuario INT,
    nombre VARCHAR(120),
    telefono VARCHAR(10),
    numero_licencia VARCHAR(50),
    vencimiento_licencia DATE,
    fecha_ingreso DATE,
    estado INT DEFAULT 1
);

CREATE TABLE ventas(
    pk_venta INT PRIMARY KEY AUTO_INCREMENT,
    fk_cliente INT,
    fk_usuario INT,
    fk_metodo_pago INT,
    fk_recoleccion INT,
    folio VARCHAR(50),
    fecha_venta DATETIME,
    subtotal DECIMAL(10,2),
    iva DECIMAL(10,2),
    total DECIMAL(10,2),
    observaciones VARCHAR(255),
    estado INT DEFAULT 1
);

CREATE TABLE ventas_detalle(
    pk_venta_detalle INT PRIMARY KEY AUTO_INCREMENT,
    fk_venta INT,
    fk_desecho INT,
    cantidad DECIMAL(10,2),
    precio_unitario DECIMAL(10,2),
    subtotal DECIMAL(10,2),
    estado INT DEFAULT 1
);

CREATE TABLE metodos_pago(
    pk_metodo_pago INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(120),
    descripcion VARCHAR(255),
    estado INT DEFAULT 1
);

CREATE TABLE manifiestos(
    pk_manifiesto INT PRIMARY KEY AUTO_INCREMENT,
    fk_recoleccion INT,
    fk_cliente INT,
    fk_chofer INT,
    folio VARCHAR(50),
    fecha_emision DATETIME,
    fecha_entrega DATETIME,
    origen VARCHAR(255),
    destino VARCHAR(255),
    observaciones VARCHAR(255),
    estado INT DEFAULT 1
);

CREATE TABLE manifiestos_detalle(
    pk_manifiesto_detalle INT PRIMARY KEY AUTO_INCREMENT,
    fk_manifiesto INT,
    fk_desecho INT,
    cantidad DECIMAL(10,2),
    peso DECIMAL(10,2),
    unidad_medida VARCHAR(50),
    descripcion VARCHAR(255),
    estado INT DEFAULT 1
);

CREATE TABLE viaticos(
    pk_viatico INT PRIMARY KEY AUTO_INCREMENT,
    fk_chofer INT,
    fk_ruta INT,
    fk_usuario INT,
    fecha DATETIME,
    monto_asignado DECIMAL(10,2),
    monto_gastado DECIMAL(10,2),
    observaciones VARCHAR(255),
    estado INT DEFAULT 1
);

CREATE TABLE viaticos_detalle(
    pk_viatico_detalle INT PRIMARY KEY AUTO_INCREMENT,
    fk_viatico INT,
    concepto VARCHAR(120),
    descripcion VARCHAR(255),
    cantidad DECIMAL(10,2),
    monto DECIMAL(10,2),
    fecha_gasto DATETIME,
    comprobante VARCHAR(255),
    estado INT DEFAULT 1
);

CREATE TABLE cortes(
    pk_corte INT PRIMARY KEY AUTO_INCREMENT,
    fk_usuario INT,
    fk_turno INT,
    fecha_inicio DATETIME,
    fecha_fin DATETIME,
    monto_inicial DECIMAL(10,2),
    total_ventas DECIMAL(10,2),
    total_gastos DECIMAL(10,2),
    monto_final DECIMAL(10,2),
    observaciones VARCHAR(255),
    estado INT DEFAULT 1
);

CREATE TABLE cortes_detalle(
    pk_corte_detalle INT PRIMARY KEY AUTO_INCREMENT,
    fk_corte INT,
    fk_venta INT,
    fk_metodo_pago INT,
    concepto VARCHAR(120),
    monto DECIMAL(10,2),
    fecha DATETIME,
    observaciones VARCHAR(255),
    estado INT DEFAULT 1
);

CREATE TABLE colonias(
    pk_colonias INT PRIMARY KEY AUTO_INCREMENT,
    fk_sector INT,
    nombre VARCHAR(120),
    municipio VARCHAR(120),
    ciudad VARCHAR(120),
    estado_republica VARCHAR(120),
    codigo_postal VARCHAR(10),
    estado INT DEFAULT 1
);

CREATE TABLE turnos(
    pk_turno INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(120),
    descripcion VARCHAR(255),
    hora_inicio TIME,
    hora_fin TIME,
    estado INT DEFAULT 1
);


-- ----------------------------- INSERTS ----------------------------------------

-- USUARIOS
INSERT INTO usuarios(fk_rol, usuario, nombre, correo, pass, fecha_creacion) VALUES
(2, 'vendedor1', 'Martín Vendedor', 'martinv@gmail.com', 'MTIzNDU=', NOW()),
(3, 'cobrador1', 'Josepe Cobrador', 'josepec@gmail.com', 'MTIzNDU=', NOW()),
(4, 'cliente1', 'Erick Cliente', 'erickcl@gmail.com', 'MTIzNDU=', NOW());

-- ROLES
INSERT INTO roles(nombre, descripcion) VALUES
('admin', 'Administrador'),
('vendedor', 'Vendedor'),
('cobrador', 'Cobrador'),
('cliente', 'Cliente');

-- CLIENTES
INSERT INTO clientes(fk_usuario, nombre, telefono, correo, fk_actividad_comercial, razon_social, rfc, direccion, fk_colonia, codigo_postal, fecha_registro)
VALUES(3, 'Erick Cliente', '4721234567', 'erickcl@gmail.com', 1, 'Hospital Médica San José S.A. de C.V.', 'EKU9003173C9', 'Pedro Moreno #110', 1, '37000', NOW());

-- ACTIVIDADES COMERCIALES
INSERT INTO actividades_comerciales(pk_actividad_comercial, nombre, descripcion) VALUES
(1, 'Hospitales y Sanatorios Privados', 'Hospitalización y atención médica de alta complejidad'),
(2, 'Clínicas y Consultorios Médicos/Dentales', 'Atención médica general, especialidades y odontología'),
(3, 'Laboratorios de Análisis Clínicos', 'Toma, procesamiento y análisis de muestras biológicas'),
(4, 'Clínicas Veterinarias', 'Atención médica y quirúrgica animal'),
(5, 'Industria Farmacéutica y Química', 'Manufactura de medicamentos y síntesis de químicos');

-- SECTORES
INSERT INTO sectores(pk_sector, nombre, descripcion) VALUES
(1, 'Sector Centro', 'Zona centro histórico y comercial adyacente'),
(2, 'Sector Norte - Campestre', 'Zona residencial y comercial del norte de la ciudad'),
(3, 'Sector Sur - Industrial', 'Parques industriales, Salida a Cdmx / Silao'),
(4, 'Sector Oriente - Delta', 'Zona habitacional e industrial sobre el eje Delta'),
(5, 'Sector Poniente - San Juan Bosco', 'Zona comercial y habitacional del poniente');

-- DESECHOS
INSERT INTO desechos(pk_desecho, nombre, descripcion, tipo, unidad_medida, precio) VALUES
(1, 'Punzocortantes (Bote Rojo)', 'Agujas, bisturís, lancetas y portaobjetos usados', 'RPBI - Punzocortantes', 'Kg', 45.00),
(2, 'Residuos Patológicos (Bolsa Amarilla)', 'Tejidos, órganos, biopsias y muestras anatómicas', 'RPBI - Patológicos', 'Kg', 60.00),
(3, 'No Anatómicos (Bolsa Roja)', 'Gasas, compresas, guantes con sangre y material de curación', 'RPBI - No Anatómicos', 'Kg', 35.00),
(4, 'Sangre Líquida y Fluidos', 'Muestras de sangre, plasma y fluidos biológicos', 'RPBI - Líquidos', 'Litros', 55.00),
(5, 'Reactivos y Solventes Caducados', 'Solventes químicos, reactivos de laboratorio y diagnóstico', 'Químicos Peligrosos', 'Litros', 80.00),
(6, 'Medicamentos Caducados / Citotóxicos', 'Fármacos caducados y residuos de quimioterapias', 'Fármacos / Peligrosos', 'Kg', 75.00),
(7, 'Fijadores / Reveladores de Rayos X', 'Líquidos químicos de procesamiento radiológico', 'Tóxicos Químicos', 'Litros', 50.00);

-- CHOFERES
INSERT INTO choferes(fk_usuario, nombre, telefono, numero_licencia, vencimiento_licencia, fecha_ingreso)
VALUES(2, 'Josepe Cobrador', '4770001234', 'LIC-GTO-2024-9872', '2028-12-31', '2024-01-15');

-- METODOS DE PAGO
INSERT INTO metodos_pago(nombre, descripcion) VALUES
('Efectivo', 'Efectivo'),
('Transferencia', 'Transferencia'),
('Tarjeta Débito/Crédito', 'Tarjeta'),
('Cheque', 'Cheque');

-- COLONIAS
INSERT INTO colonias(pk_colonias, fk_sector, nombre, municipio, ciudad, estado_republica, codigo_postal) VALUES
(1, 1, 'Centro', 'León', 'León', 'Guanajuato', '37000'),
(2, 1, 'San Juan de Dios', 'León', 'León', 'Guanajuato', '37004'),
(3, 1, 'Obregón', 'León', 'León', 'Guanajuato', '37320'),
(4, 2, 'Jardines del Moral', 'León', 'León', 'Guanajuato', '37160'),
(5, 2, 'Campestre', 'León', 'León', 'Guanajuato', '37150'),
(6, 2, 'Valle del Campestre', 'León', 'León', 'Guanajuato', '37150'),
(7, 3, 'Industrial Julián de Obregón', 'León', 'León', 'Guanajuato', '37290'),
(8, 3, 'Parque Industrial Stiva', 'León', 'León', 'Guanajuato', '37545'),
(9, 4, 'Delta', 'León', 'León', 'Guanajuato', '37545'),
(10, 4, 'El Coecillo', 'León', 'León', 'Guanajuato', '37260'),
(11, 5, 'San Juan Bosco', 'León', 'León', 'Guanajuato', '37330'),
(12, 5, 'Vibar', 'León', 'León', 'Guanajuato', '37353');

-- TURNOS
INSERT INTO turnos(nombre, descripción, hora_inicio, hora_fin) VALUES
('Matutino', 'Turno en la mañana', '09:00:00', '13:30:00'),
('Vespertino', 'Turno en la tarde', '13:30:00', '18:00:00');



