CREATE TABLE drivers (
    driver_id SERIAL PRIMARY KEY,
    company_name TEXT NOT NULL,      
    driver_name TEXT NOT NULL UNIQUE,      
    truck_number TEXT, 
    is_active BOOLEAN DEFAULT TRUE,            
    statement_type TEXT CHECK (statement_type IN ('company', 'individual')) DEFAULT 'company'
);

CREATE TABLE rates (
    rate_id SERIAL PRIMARY KEY,
    pick_up TEXT NOT NULL,
    drop_off TEXT NOT NULL,
    company_name TEXT, 
    rate_per_ton DECIMAL(10, 2),
    rate_type TEXT CHECK (rate_type IN ('per_ton', 'flat')) DEFAULT 'per_ton',
    apply_fsc BOOLEAN DEFAULT TRUE,
    start_date DATE NOT NULL DEFAULT '2025-01-01',
    end_date DATE NOT NULL DEFAULT '2099-12-31'
);

CREATE TABLE fsc_rates (
    id SERIAL PRIMARY KEY,
    fsc_percentage DECIMAL(5, 2) NOT NULL, 
    start_date DATE NOT NULL DEFAULT '2025-01-01',
    end_date DATE NOT NULL DEFAULT '2099-12-31'
);

CREATE TABLE dispatch_rates (
    id SERIAL PRIMARY KEY,
    company_name TEXT NOT NULL,
    fee_percentage DECIMAL(5, 2) NOT NULL DEFAULT 8.00, 
    start_date DATE NOT NULL DEFAULT '2025-01-01',
    end_date DATE NOT NULL DEFAULT '2099-12-31'
);

CREATE TABLE loads (
    load_id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    company_name TEXT,
    driver_name TEXT NOT NULL,      
    delivery_date DATE NOT NULL,
    truck_number TEXT NOT NULL,  
    ticket_number TEXT NOT NULL UNIQUE,
    material TEXT,
    pick_up TEXT NOT NULL,
    drop_off TEXT NOT NULL,
    tons DECIMAL(10, 2) NOT NULL,
    ticket_image_url TEXT,              
    CONSTRAINT fk_driver FOREIGN KEY (driver_name) REFERENCES drivers(driver_name)
);

-- For the typo-resistant joins
CREATE INDEX idx_drivers_name_clean ON drivers(driver_name);
CREATE INDEX idx_loads_driver_clean ON loads(driver_name);

-- For the route and date lookups
CREATE INDEX idx_rate_lookup ON rates(pick_up, drop_off, start_date, end_date);
CREATE INDEX idx_fsc_date ON fsc_rates(start_date, end_date);
CREATE INDEX idx_dispatch_date ON dispatch_rates(company_name, start_date, end_date);
CREATE INDEX idx_loads_date ON loads(delivery_date);



INSERT INTO drivers (company_name, driver_name, truck_number)
VALUES 
('Allcon', 'Carlos Contreras', '05'),
('Allcon', 'Jose', '01'),
('Allcon', 'Jordy Barrientos', '05'),
('A. Llamas Trucking', 'Audel LLamas', '242'),
('Jha Trucking Inc', 'Jorge Anaya', '208-209-210'),
('De Alba Trucking LLC', 'Mario de Alba', '211'),
('Baca Transport Inc', 'Alex Mejia', '220'),
('Baca Transport Inc', 'Eric Torres', '253'),
('Marvin G Davila', 'Marvin Gonzalez', '234'),
('Marvin G Davila', 'Juan', '238'),
('F. LLamas Trucking Inc', 'Federico Llamas', '241-245'),
('F. LLamas Trucking Inc', 'Josmel', '244'),
('F. LLamas Trucking Inc', 'Raul Orozco', '246'),
('F. LLamas Trucking Inc', 'Javier Jordan', '247'),
('YESFAP Trucking LLC', 'Pedro Enrique Llamas', '254'),
('G Martinez Trucking LLC', 'Gabriel Martinez', '306'),
('KNM Transport', 'Chris', '212'),
('KNM Transport', 'Irvin', '213'),
('KNM Transport', 'Jose Gonzalez', '225'),
('KVS Transport Inc', 'Juan Jimenez', '239-240'),
('B. Ruiz Trucking', 'Julio', '303'),
('LGS Transport', 'Luis Salas', '233'),
('G Martin LLC', 'Martin Gonzalez', '206'),
('G Martin LLC', 'Evan', '207'),
('G Martin LLC', 'Rene Fernandez', '249-251'),
('MRL Trucking LLC', 'Max Lopez', '230'),
('MHG Logistics', 'Herrera', '224'),
('Jip & Sons Inc', 'Jose Perez', '232'),
('Patria Robledo Transportation', 'Patricia Robledo', '205'),
('O. Renteria Trucking Inc', 'Osvaldo Renteria', '243'),
('Rony G Trucking Inc', 'Rony', '231'),
('J.F. Salgado Trucking', 'Ivan', '222-250-252'),
('Spartan Transport LLC', 'Jesse Rivera', '237'),
('Naranjo Trucking Inc', 'Sergio Santana', '219');

INSERT INTO rates (pick_up, drop_off, rate_per_ton, apply_fsc, start_date, end_date)
VALUES
('Cemex Bell', 'Cemex Inglewood', 5.85, TRUE, '2025-01-01', '2099-12-31'),
('Cemex Bell', 'Cemex Orange', 6.60, TRUE, '2025-01-01', '2099-12-31'),
('Cemex Bell', 'Cemex Walnut', 6.00, TRUE, '2025-01-01', '2099-12-31'),
('Cemex Lytle Creek', 'Cemex Orange', 8.50,TRUE, '2025-01-01', '2099-12-31'),
('Cemex Lytle Creek', 'Cemex Fontana', 4.10,TRUE, '2025-01-01', '2099-12-31'),
('Cemex Lytle Creek', 'Cemex Inglewood', 12.75, TRUE, '2025-01-01', '2099-12-31'),
('Cemex Lytle Creek', 'Cemex Irvine', 10.10, TRUE, '2025-01-01', '2099-12-31'),
('Cemex Lytle Creek', 'Cemex Walnut', 7.85, TRUE, '2025-01-01', '2099-12-31'),
('Cemex White Mountain', 'Cemex Fontana', 11.55, TRUE, '2025-01-01', '2099-12-31'),
('Cemex White Mountain', 'Cemex Inglewood', 19.95, TRUE, '2025-01-01', '2026-04-08'),
('Cemex White Mountain', 'Cemex Inglewood', 24.25, FALSE, '2026-04-09', '2026-04-16'),
('Cemex White Mountain', 'Cemex Inglewood', 25.60, FALSE, '2026-04-17', '2099-12-31'),
('Cemex White Mountain', 'Cemex Orange', 19.30, FALSE, '2025-01-01', '2099-12-31'),
('Cemex White Mountain', 'Cemex LA', 22.00, FALSE, '2025-01-01', '2099-12-31'),
('Cemex White Mountain', 'Cemex Walnut', 18.25, FALSE, '2025-01-01', '2099-12-31'),
('Cemex White Mountain', 'Cemex Bell', 25.60, FALSE, '2025-01-01', '2099-12-31'),
('Cemex Compton', 'Cemex Inglewood', 4.30, FALSE, '2025-01-01', '2099-12-31'),
('Cemex Inglewood', 'Cemex Orange', 9.00, FALSE, '2025-01-01', '2099-12-31'),
('Cemex Fontana', 'Cemex Inglewood', 11.00, FALSE, '2025-01-01', '2099-12-31'),
('Cemex Moorepark', 'Cemex Inglewood', 11.40,TRUE, '2025-01-01', '2099-12-31');



INSERT INTO rates (pick_up, drop_off, company_name, rate_per_ton, apply_fsc, start_date, end_date)
VALUES
('Cemex Bell', 'Cemex Inglewood', 'KNM Transport', 6.10, TRUE, '2025-01-01', '2099-12-31'),
('Cemex Moorepark', 'Cemex Inglewood', 'B. Ruiz Trucking', 12.15, TRUE, '2025-01-01', '2099-12-31');

INSERT INTO rates (pick_up, drop_off, rate_per_ton, rate_type, apply_fsc, start_date, end_date)
VALUES
('Cemex Inglewood', 'Cemex Moorepark', 100.00, 'flat', TRUE, '2025-01-01', '2099-12-31');

INSERT INTO dispatch_rates (company_name)
VALUES
('Allcon'),
('A. Llamas Trucking'),
('Jha Trucking Inc'),
('De Alba Trucking LLC'),
('Baca Transport Inc'),
('Marvin G Davila'),
('F. LLamas Trucking Inc'),
('YESFAP Trucking LLC'),
('G Martinez Trucking LLC'),
('KNM Transport'),
('KVS Transport Inc'),
('B. Ruiz Trucking'),
('LGS Transport'),
('G Martin LLC'),
('MRL Trucking LLC'),
('MHG Logistics'),
('Jip & Sons Inc'),
('Patria Robledo Transportation'),
('O. Renteria Trucking Inc'),
('Rony G Trucking Inc'),
('J.F. Salgado Trucking'),
('Spartan Transport LLC'),
('Naranjo Trucking Inc');

INSERT INTO fsc_rates (fsc_percentage, start_date, end_date)
VALUES
(0.00, '2025-01-01', '2026-03-03'),
(2.26, '2026-03-04', '2026-03-31'),
(8.00, '2026-04-01', '2026-04-08'),
(11.50, '2026-04-09', '2099-12-31');


SELECT row_number() OVER (ORDER BY created_at ASC) as load_number, * FROM loads;

UPDATE loads
SET statement_date = delivery_date;


UPDATE loads
SET company_name = 'Barcenas Trucking'
WHERE driver_name = 'Barcenas';

WITH reordered AS (
    SELECT 
        load_id, 
        ROW_NUMBER() OVER (ORDER BY created_at ASC) as new_id
    FROM loads
)

UPDATE loads SET load_id = load_id + 10000;

-- 2. Reassign IDs starting from 1 based on the oldest 'created_at'
WITH reordered AS (
    SELECT 
        load_id, 
        ROW_NUMBER() OVER (ORDER BY created_at ASC) as new_seq
    FROM loads
)
UPDATE loads
SET load_id = reordered.new_seq
FROM reordered
WHERE loads.load_id = reordered.load_id;

SELECT setval(pg_get_serial_sequence('loads', 'load_id'), COALESCE(MAX(load_id), 1)) 
FROM loads;
