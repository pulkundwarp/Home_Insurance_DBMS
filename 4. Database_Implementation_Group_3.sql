-- Part 1 Create Tables

CREATE TABLE CustomerSource (
	customer_source_id int IDENTITY NOT NULL PRIMARY KEY,
	source_name varchar(40));
CREATE TABLE CommunityEnvironment (
	zipcode varchar(40) NOT NULL PRIMARY KEY,
	crime_rate int,
	population int,
	earthquake_rate int,
	fire_rate int,
	flood_freq int);
CREATE TABLE CoverageOptions (
	coverage_id int IDENTITY NOT NULL PRIMARY KEY,
	coverage_name varchar(40));
CREATE TABLE Address (
	address_id int IDENTITY NOT NULL PRIMARY KEY,
	address_line1 varchar(40),
	address_line2 varchar(40),
	city varchar(40),
	state varchar(40),
	zipcode varchar(40) REFERENCES CommunityEnvironment(zipcode));
CREATE TABLE HouseInfo (
	house_id int IDENTITY NOT NULL PRIMARY KEY,
	build_year int,
	renovated_year int,
	floors int,
	house_area int,
	replacement_cost money,
	construction_type varchar(40),
	address_id int REFERENCES Address(address_id),
	condition_level int,
	main_road_distance float,
	fire_station_distance float,
	river_distance float);
CREATE TABLE InternalPossession (
    house_id int NOT NULL REFERENCES HouseInfo(house_id),
    item_name varchar(40),
    value money
    CONSTRAINT PKInternalPossession PRIMARY KEY CLUSTERED
             (house_id, item_name));
CREATE TABLE SecuritySystem (
    house_id int NOT NULL REFERENCES HouseInfo(house_id),
    system_type  varchar(40)
    CONSTRAINT PKSecuritySystem PRIMARY KEY CLUSTERED
             (house_id, system_type));      
CREATE TABLE CustomerInfo (
	customer_id int IDENTITY NOT NULL PRIMARY KEY,
	SSN varchar(40),
	first_name varchar(40),
	middle_name varchar(40),
	last_name varchar(40),
	sex varchar(40),
	birth_date date,
	address_id int REFERENCES Address(address_id),
	phone varchar(40),
	smoking varchar(40),
	highest_education varchar(40),
	credit_score int,
	credit_date date,
	customer_source_id int REFERENCES CustomerSource(customer_source_id));
CREATE TABLE CasePortal (
	case_id int IDENTITY NOT NULL PRIMARY KEY,
	customer_id int REFERENCES CustomerInfo(customer_id),
	house_id int REFERENCES HouseInfo(house_id),
	start_date date,
	end_date date,
	deductible_amount int,
	limit int);
CREATE TABLE CaseCoverage (
	case_id int NOT NULL REFERENCES CasePortal(case_id),
	coverage_id int NOT NULL REFERENCES CoverageOptions(coverage_id)
    CONSTRAINT PKCaseCoverage PRIMARY KEY CLUSTERED
             (case_id, coverage_id));
CREATE TABLE ClaimHistory (
	claim_id int IDENTITY NOT NULL PRIMARY KEY,
	house_id int REFERENCES HouseInfo(house_id),
	customer_id int REFERENCES CustomerInfo(customer_id),
	claim_date date);
CREATE TABLE Payment (
	payment_id int IDENTITY NOT NULL PRIMARY KEY,
	claim_id int REFERENCES ClaimHistory(claim_id),
	coverage_id int REFERENCES CoverageOptions(coverage_id),
	amount_paid money,
    payment_status varchar(40)); 
   
-- Part 2 Computed Columns based on a function

-- 1) Insert email address by referring from existed BD
CREATE FUNCTION add_email (@CustID INT)
RETURNS varchar(40)
AS 
BEGIN 
DECLARE @email varchar(40) = 
    (SELECT EmailAddress
	 FROM AdventureWorks2008R2.Person.EmailAddress
	 WHERE BusinessEntityID = @CustID);
	 SET @email = COALESCE(@email, '')
  RETURN @email;
END;
 
-- Add a computed column to the dbo.CustomerInfo
ALTER TABLE dbo.CustomerInfo
ADD email_address AS (dbo.add_email(customer_id));   

-- 2) Create a function to calculate customer's age
CREATE FUNCTION add_age
(@CustID INT)
RETURNS INT
AS
BEGIN
DECLARE @DateOfBirth date =
(SELECT birth_date
FROM dbo.CustomerInfo
WHERE customer_id = @CustID)
; 
DECLARE @age INT = DATEDIFF(hour, @DateOfBirth, GETDATE())/8766

RETURN @age;
END;
-- Add a computed column to the dbo.CustomerInfo
ALTER TABLE dbo.CustomerInfo
ADD age AS (dbo.add_age(customer_id));   

-- 3) Calculate the total InternalPossession value for each house
CREATE FUNCTION total_Possession_value(@houseID INT)
RETURNS MONEY
AS
   BEGIN
      DECLARE @total MONEY =
         (SELECT SUM(value)
          FROM InternalPossession
          WHERE house_id = @houseID);
      SET @total = ISNULL(@total, 0);
      RETURN @total;
END;  
 -- Add a computed column to the dbo.HouseInfo
ALTER TABLE HouseInfo
ADD internal_possession_value AS (dbo.total_Possession_value(house_id));

-- Part 3 Table-level CHECK Constraints based on a function

-- 1) Prevent address insertion if the crime rate >= 65%​
CREATE FUNCTION CheckCrime
(@zipcode varchar(40))
RETURNS INT
AS 
BEGIN 
DECLARE @crime_rate int =
       (SELECT crime_rate
       FROM CommunityEnvironment
	   WHERE zipcode = @zipcode);
RETURN @crime_rate;
END;

ALTER TABLE dbo.Address ADD CONSTRAINT HighCrime CHECK (dbo.CheckCrime(zipcode)<65);  

-- 2) create a trigger to prevents the input value to be zero in 'amount_paid'
CREATE TRIGGER CheckAmount
ON dbo.Payment
AFTER INSERT, UPDATE
AS
	IF EXISTS
		(
			SELECT 'True'
			FROM Inserted i
			JOIN dbo.Payment p
				ON i.payment_id = p.payment_id
			WHERE p.amount_paid = 0
		)
	BEGIN
		RAISERROR('The amount_paid field can not be zero. Please insert a correct value.', 15, 1)
		ROLLBACK TRAN	
	END;

-- 3)For house with more than 5 claim history, prevent it from enrolling new case
   
create function house_claim_check (@houseID int)
returns smallint
begin
   declare @claim_count int;
   select @claim_count = count(distinct claim_id)
      from ClaimHistory
      where house_id = @houseID;
   return @claim_count;
end;

alter table CasePortal add CONSTRAINT Claim_History_Check CHECK (dbo.house_claim_check (house_id) <= 5);
    
-- Part 4 implement basic data
INSERT dbo.CustomerSource
VALUES('Real estate agents'),
      ('Mortgage brokers'),
	  ('Financial planners'),
	  ('Accountants'),
	  ('TV'),
	  ('Newspaper'),
	  ('Twitter'),
	  ('Facebook'),
	  ('Instagram'),
	  ('Friends'),
	  ('Business seminars'),
	  ('Charity events'),
	  ('Phone Call'),
	  ('Company Website'),
	  ('In-person'),
	  ('Live chat'),
	  ('Email'),
	  ('Local Event');
--data scource--http://zipatlas.com/us/ma/zip-code-comparison/population-density.htm
INSERT dbo.CommunityEnvironment
VALUES('02108', 6, 6401, 0, 2, 3),
      ('02109', 7, 25486, 0, 2, 4),
	  ('02110', 2, 19682, 0, 3, 2),
	  ('02111', 1, 21963, 0, 4, 1),
	  ('02112', 1, 25058, 1, 6, 2),
	  ('02113', 2, 29555, 2, 4, 9),
	  ('02114', 3, 34682, 3, 8, 8),
	  ('02115', 5, 22173, 4, 5, 6),
	  ('02116', 7, 3428, 5, 6, 0),
	  ('02117', 10, 10828, 6, 3, 0),
	  ('02118', 12, 1005, 1, 10, 4),
	  ('02119', 2, 420, 1, 1, 3),
	  ('02120', 3, 3446, 1, 2, 2),
	  ('02121', 4, 35407, 3, 3, 2),
	  ('02122', 18, 15295, 2, 5, 4),
	  ('02123', 20, 33681, 1, 4, 6),
	  ('02124', 17, 32527, 3, 2, 6),
	  ('02125', 15, 38057, 10, 3, 5),
	  ('02126', 10, 19737, 9, 5, 8),
	  ('02127', 8, 23773, 8, 4, 9),
	  ('02128', 6, 15992, 7, 3, 8),
	  ('02129', 5, 13138, 7, 2, 9),
	  ('02130', 4, 4732, 6, 5, 10),
	  ('02131', 3, 17433, 6, 4, 11),
	  ('02132', 1, 11333, 5, 10, 12),
	  ('02133', 1, 1191, 5, 8, 12),
	  ('02134', 1, 1428, 5, 9, 13),
	  ('02135', 1, 2978, 4, 7, 14),
	  ('02136', 1, 18303, 4, 6, 15),
	  ('02137', 1, 248, 3, 5, 16),
	  ('02138', 2, 36293, 3, 4, 17),
	  ('02139', 2, 32989, 3, 3, 18),
	  ('02140', 2, 26787, 2, 3, 19),
	  ('02141', 4, 28392, 2, 2, 20),
	  ('02142', 4, 17467, 2, 2, 16),
	  ('02143', 10, 2936, 1, 2, 12),
	  ('02144', 12, 21199, 1, 1, 10),
	  ('02145', 11, 11078, 0, 1, 9),
	  ('02146', 12, 6272, 0, 0, 3),
	  ('02147', 12, 25343, 1, 0, 1),
	  ('02148', 62, 6378, 0, 3, 2),
	  ('02149', 70, 4178, 4, 2, 1);	 	 
INSERT INTO dbo.CoverageOptions(coverage_name)
VALUES
	('House'),
	('Other Structure'),
	('Personal Property'),
	('Alternate Living Arrangements'),
	('Personal Liability Lawsuits'),
	('Medical Payments'),
	('fire'),
	('Floods'),
	('Earthquakes'),
	('Windstorm'),
	('Poor Maintenance'),
	('Internal Accidental Damage'),
	('External Accidental Damage');
-- data source--https://www.kaggle.com/datasets/openaddresses/openaddresses-us-west?select=ca.csv
INSERT dbo.Address
VALUES('508 FRANKLIN ST','Unit A', 'Boston', 'Massachusetts', '02108'),
      ('1223 FRANKLIN ST', 'Unit A', 'Boston', 'Massachusetts', '02109'),
	  ('216 PARK BL', 'Unit B','Boston', 'Massachusetts', '02108'),
	  ('240 PARK BL', 'Unit C','Boston', 'Massachusetts', '02110'),
	  ('3 CANON AV', NULL ,'Boston', 'Massachusetts', '02111'),
	  ('2 DAKOTA ST', 'Unit 202','Boston', 'Massachusetts', '02112'),
	  ('35 KELTON CT', 'Unit 101','Worcester', 'Massachusetts', '02113'),
	  ('26 KELTON CT', 'Unit 303', 'Worcester', 'Massachusetts', '02113'),
	  ('23 FOOTHILL BL', 'Unit 4B','Somerville', 'Massachusetts', '02114'),
	  ('34 FOOTHILL BL', 'Unit 6C','Somerville', 'Massachusetts', '02115'),
	  ('56 FOOTHILL BL', NULL,'Somerville', 'Massachusetts', '02115'),
	  ('201 66TH ST', 'Unit 101','Somerville', 'Massachusetts', '02116'),
	  ('33 66TH ST', 'Unit 103','Somerville', 'Massachusetts', '02115'),
	  ('24 66TH ST', 'Unit 202','Somerville', 'Massachusetts', '02114'),
	  ('334 SHEFFIELD RD', 'Unit A','Somerville', 'Massachusetts', '02117'),
	  ('366 SHEFFIELD RD', 'Unit B','Somerville', 'Massachusetts', '02118'),
	  ('3531 SILVA LN', 'Unit 222','Cambridge', 'Massachusetts', '02120'),
	  ('3561 SILVA LN', 'Unit 223','Cambridge', 'Massachusetts', '02121'),
	  ('3577 SILVA LN', 'Unit 401','Cambridge', 'Massachusetts', '02121'),
	  ('1011 CAMELLIA DR', NULL,'Cambridge', 'Massachusetts', '02122'),
	  ('1015 CAMELLIA DR', 'Unit C','Cambridge', 'Massachusetts', '02123'),
	  ('1030 CAMELLIA DR', 'Unit C','Cambridge', 'Massachusetts', '02122'),
	  ('7 DAHLIA DR', 'Unit A','Brookline', 'Massachusetts', '02125'),
	  ('9 DAHLIA DR', 'Unit A','Brookline', 'Massachusetts', '02126'),
	  ('123 BEGONIA DR', NULL,'Brookline', 'Massachusetts', '02127'),
	  ('321 BEGONIA DR', 'Unit 201','Brookline', 'Massachusetts', '02126'),
	  ('555 BEGONIA DR', 'Unit 202','Brookline', 'Massachusetts', '02125'),
	  ('602 EGRET CT', 'Unit A','Brookline', 'Massachusetts', '02126'),
	  ('570 AMBER ISLE', 'Unit C','Lawrence', 'Massachusetts', '02131'),
	  ('573 AMBER ISLE', 'Unit B','Lawrence', 'Massachusetts', '02133'),
	  ('577 AMBER ISLE', NULL,'Lawrence', 'Massachusetts', '02133'),
	  ('180 MAPLE WY', 'Unit 101','Lawrence', 'Massachusetts', '02134'),
	  ('181 MAPLE WY', 'Unit 202','Lawrence', 'Massachusetts', '02135'),
	  ('190 MAPLE WY', 'Unit 203','Lawrence', 'Massachusetts', '02136'),
	  ('550 CORPUS CHRISTI RD', 'Unit 201', 'Springfield', 'Massachusetts', '02140'),
	  ('560 CORPUS CHRISTI RD', NULL,'Springfield', 'Massachusetts', '02141'),
	  ('1675 TAYLOR AV', 'Unit 202','Springfield', 'Massachusetts', '02141'),
	  ('2381 TAYLOR AV', 'Unit 206','Springfield', 'Massachusetts', '02140'),
	  ('425 PACIFIC AV', 'Unit 301','Quincy',' Massachusetts', '02143'),
	  ('667 PACIFIC AV', 'Unit 302','Quincy',' Massachusetts', '02147');   
INSERT dbo.HouseInfo(address_id, floors, house_area, replacement_cost, 
                     construction_type, condition_level, main_road_distance, fire_station_distance, river_distance, renovated_year, build_year)
VALUES  (1,	1,	900,	3789,	'Fire-resistive Type I (IA and IB)',     3,	11.2,  0.8,	     8,	   2010,	1998),
		(2,	1,	1000,	7680,	'Non-combustible Type II (IIA and IIB)', 1,	1.2,	12.4,	1.4,	2007,	2004),
		(3,	3,	1285,	4340,	'Ordinary Type III',	                 1,	9.5,	10.5,	 15,	2011,	2010),
		(4,	2,	2000,	6210,	'Heavy Timber Type IV',	                 3,	4.5,	4,	      6,	2021,	2001),
		(5,	1,	885,	1200,	'Wood-Framed Type V',	                 4,	1,	       5,	1,	            2005,	1996),
		(6,	1,	750,	9000,	'Non-combustible Type II (IIA and IIB)', 2,	8,	9.5,	8.5,	2021,	1999),
		(7,	2,	1000,	4500,	'Ordinary Type III',	3,	10,	11,	1,	2017,	2007),
		(8,	2,	1900,	3051,	'Wood-Framed Type V',	4,	15,	0.8,	8,	2005,	2001),
		(9,	3,	700,	4000,	'Non-combustible Type II (IIA and IIB)',	4,	3.5,	5.6,	2,	2011,	2008),
		(10,	1,	590,	3250,	'Ordinary Type III',	1,	0.5,	20,	17,	2017,	2007),
		(11,	1,	1000,	12350,	'Heavy Timber Type IV',	1,	4,	17,	7,	NULL,	1996),
		(12,	1,	1250,	750,	'Ordinary Type III',	4,	2,	4.5,	2.3,	2005,	2004),
		(13,	2,	700,	5842,	'Non-combustible Type II (IIA and IIB)',	2,	0.5,	5,	15,	2021,	1996),
		(14,	1,	2250,	5489,	'Wood-Framed Type V',	3,	2,	18,	8,	2021,	2008),
		(15,	2,	1000,	9876,	'Non-combustible Type II (IIA and IIB)',	1,	8,	5,	4,	2008,	1998),
		(16,	1,	1200,	1000,	'Heavy Timber Type IV',	5,	4,	4.5,	5,	2007,	1998),
		(17,	3,	900,	5320,	'Wood-Framed Type V',	2,	0.5,	9,	0.45,	2007,	2004),
		(18,	3,	850,	3400,	'Ordinary Type III',	3,	7.5,	7,	8.5,	NULL,	2007),
		(19,	1,	600,	800,	'Non-combustible Type II (IIA and IIB)',	5,	2.4,	4.5,	2.5,	NULL,	2010),
		(20,	3,	750,	2020,	'Heavy Timber Type IV',	4,	5.6,	9,	8,	NULL,	2001),
		(21,	1,	800,	4670,	'Non-combustible Type II (IIA and IIB)',	3,	19,	2,	1,	2019,	1996),
		(22,	3,	1000,	18880,	'Non-combustible Type II (IIA and IIB)',	1,	20,	10.5,	1.5,	2010,	2001),
		(23,	2,	1025,	2360,	'Heavy Timber Type IV',	2,	4.5,	6,	9,	2005,	1998),
		(24,	3,	960,	1508,	'Wood-Framed Type V',	5,	3.4,	4,	2,	NULL,	2001),
		(25,	2,	1000,	8400,	'Heavy Timber Type IV',	1,	9,	7,	19.5,	2010,	2008),
		(26,	1,	1250,	3670,	'Non-combustible Type II (IIA and IIB)',	4,	0.7,	7.5,	1.4,	2021,	2008);
INSERT INTO dbo.SecuritySystem(house_id, system_type) 
VALUES
		(1,	'Monitored Alarm'),
		(2,	'Smoke Alarm'),
		(3,	'Intruder Alarm'),
		(4,	'CCTV Cameras'),
		(5,	'Security Guard'),
		(6,	'Smoke Alarm'),
		(7,	'Monitored Alarm'),
		(8,	'Security Guard'),
		(9,	'Intruder Alarm'),
		(10,'Security Guard'),
		(11,'Smoke Alarm'),
		(12,'Intruder Alarm'),
		(13,'Monitored Alarm'),
		(14,'Security Guard'),
		(15,'Intruder Alarm'),
		(16,'Smoke Alarm'),
		(17,'Security Guard'),
		(18,'Monitored Alarm'),
		(19,'Intruder Alarm'),
		(20,'Security Guard'),
		(21,'Monitored Alarm'),
		(22,'Intruder Alarm'),
		(23,'Monitored Alarm'),
		(24,'Security Guard'),
		(25,'Monitored Alarm'),
		(26,'Intruder Alarm');	
INSERT INTO dbo.InternalPossession(house_id, item_name, value) 
VALUES 
		(1,	'diamond necklace',	        20523),
		(1,	'antique table',	        46769),
		(2,	'emerald',	                190655),
		(4,	'wooden chair',	            37201),
		(5,	'first edition book',       22599),
		(6, 'antique cutlery',	        5694),
		(6, 'goldplated mirror',        186),
		(8, 'first edition photoframe',	199686),
		(8, 'mini ferrari ',	        4132),
		(8, 'engagement ring',	        39069),
		(9, 'silverware',	            4169),
		(10, 'firearms',                 2364),
		(10, 'stamp collections',	    14212),
		(11, 'amethyst studded box',    633),
		(11, 'furs',	                17721),
		(12, 'jewellery box',	        2581),
		(12,'goldplated mirror',        41816),
		(14,'first edition photoframe',	1986),
		(16, 'ancestral shield',	    36786),
		(16,'mini ferrari ',	        474132),
		(16,'engagement ring',	        0694),
		(18,'silverware',	            49169),
		(18,'firearms',	                23364),
		(18, 'sports equipment',        302297),
		(18, 'wooden chair',	        20201),
		(19, 'collectable comics',      1962),
		(19,'stamp collections',	    1212),
		(20, 'Picasso artwork',	        34667),
		(20,'amethyst studded box',	    6633),
		(21, 'wedding ring',	        45475),
		(21, 'antique cutlery',	        5694),
		(21, 'goldplated mirror',       4816),
		(21, 'first edition photoframe',1686),
		(21, 'mini ferrari ',	        47132),
		(21,'furs',	                    1721),
		(22,'piano',	                1452),
		(23,'fine china bowls',	        41658),
		(23,'engagement ring',	        15566),
		(24, 'engagement ring',	        3694),
		(24, 'silverware',	            49169),
		(24, 'firearms',	            234),
		(26, 'stamp collections',	    14212),
		(26, 'amethyst studded box',	3633),
		(26, 'furs',	                1721),
		(26,'antique cutlery',	        25694); 
INSERT dbo.CustomerInfo(SSN, first_name, middle_name, last_name, sex,  birth_date, address_id, phone, smoking, highest_education, credit_score, credit_date, customer_source_id )
VALUES('837-19-3842', 'Will', NULL, 'Smith', 'male', '1978-10-04',1,'697-555-0142','yes', 'bachelor', 700, '2022-01-03', 1),
      ('864-23-8071', 'James', 'Tom', 'Johnson', 'male', '1952-06-12', 2,'819-555-0175', 'no', 'bachelor', 650,'2022-02-05', 2),
	  ('217-01-6193', 'Samuel', 'Ben', 'Williams', 'male', '1985-10-26', 3,'212-555-0187','yes', 'bachelor', 670, '2021-12-10', 3),
	  ('769-53-7558', 'John', 'Francis', 'Brown', 'male', '1989-09-18', 4,'612-555-0100', 'no', 'bachelor', 660,'2022-02-05', 5),
	  ('542-50-9281', 'George', 'Marion', 'Jones', 'male', '1992-10-28',  5,'849-555-0139','yes', 'bachelor', 710, '2021-12-10', 7),
	  ('528-55-0602', 'Sam', 'Luther', 'Garcia', 'male', '1989-09-19', 6,'122-555-0189', 'no', 'bachelor', 720, '2022-01-03', 9),
	  ('495-00-2870', 'Shayna', 'Emelia', 'Miller', 'female', '1979-09-20', 7,'181-555-0156','yes', 'bachelor', 730,'2022-02-05', 11),
	  ('089-95-2067', 'Laurel', NULL,'Davis', 'female', '1973-01-01', 8,'815-555-0138', 'no', 'bachelor', 750,'2022-02-05', 15),
	  ('099-52-2802', 'Neveah', 'Micaela', 'Rodriguez', 'female', '1982-12-03',9 ,'185-555-0186','yes', 'bachelor', 760, '2022-01-03', 1),
	  ('028-71-7779', 'Makaila', 'Shea', 'Martinez', 'female', '1972-02-24', 10,'330-555-2568', 'no', 'high school', 750, '2021-12-10', 2),
	  ('633-70-2532', 'Kianna', 'Donna', 'Taylor', 'female', '1986-01-01',11,'719-555-0181','yes', 'high school', 800, '2021-12-10', 18),
	  ('001-14-2521', 'Rory', 'Esperanza', 'Lewis', 'female', '1977-09-15', 12,'168-555-0183', 'no', 'high school', 600, '2022-01-03', 12),
	  ('359-03-9546', 'Hadassah', 'Kaylah', 'Harris', 'female', '1985-02-22', 23,'473-555-0117','yes', 'high school', 700, '2021-12-10', 15),
	  ('229-97-7831', 'Amaris','Maren', 'Young', 'female', '1977-02-21',13 ,'465-555-0156', 'no', 'high school', 600, '2021-12-10', 17),
	  ('030-96-2007', 'Dania', 'Amiah', 'Allen', 'female', '1973-01-12', 14,'970-555-0138','yes', 'Master', 500, '2022-01-03', 14),
	  ('042-14-1069', 'Jamiya', NULL, 'King', 'female', '1990-09-08', 15,'913-555-0172', 'no', 'Master', 740, '2021-12-10', 12),
	  ('060-09-4578', 'Hailie', 'Avah', 'Hill', 'female', '1987-03-18', 16,'150-555-0189','yes', 'Master', 810,'2022-02-05', 16),
	  ('838-10-0474', 'Kathy', 'Alyvia', 'Green', 'female', '1972-04-12', 17,'486-555-0150', 'no', 'Master', 820, '2021-12-10', 14),
	  ('518-29-4601', 'Laylah', 'Averi', 'Bradley', 'female', '1977-07-25',18 ,'124-555-0114','yes', 'Master', 800,'2022-02-05', 17),
	  ('843-40-3310', 'Riya', 'Selina', 'Dempsey', 'female', '1986-11-19',19 ,'708-555-0141', 'no', 'Master', 790, '2021-12-10', 9),
	  ('318-35-7827', 'Sloane', 'Essence', 'Hamilton', 'female', '1974-03-07', 20,'138-555-0118','yes', 'Master', 790, '2022-01-03', 9),
	  ('459-55-1758', 'Diya', 'Desirae', 'Brown', 'female', '1984-11-14',21 ,'399-555-0176', 'no', 'Master', 780, '2021-12-10', 1),
	  ('303-21-3409', 'Kenley', 'Ashtyn', 'Gilbert', 'female', '2000-01-01',22 ,'531-555-0183','yes', 'Master', 780, '2021-12-10', 1),
	  ('879-41-6659', 'Elianna', NULL, 'Okelberry', 'female', '1974-01-09', 24,'510-555-0121', 'no', 'Master', 770, '2021-12-10', 1),
	  ('518-01-9530', 'Iyana', 'Karsyn', 'Abercrombie', 'female', '1980-08-27', 25,'870-555-0122','yes', 'Master', 770, '2022-01-03', 3),
	  ('355-56-0529', 'Carleigh', 'Miya', 'Kramer', 'female', '1989-05-05', 26,'913-555-0196', 'no', 'Master', 750, '2021-12-10', 4),
	  ('847-93-7077', 'Chana', 'Anabel', 'Michaels', 'female', '1989-03-08',27 ,'632-555-0129','yes', 'Master', 740,'2022-02-05', 4),
	  ('991-58-3877', 'Chester', 'Arthur', 'Michaels', 'male', '1973-11-16',28 ,'320-555-0195', 'no', 'Master', 740, '2021-12-10', 3),
	  ('825-31-8454', 'Lewis', 'Homer', 'Hartwig','male', '1988-08-01', 29 ,'417-555-0154','yes', 'Master', 660, '2021-12-10', 2),
	  ('296-94-8125', 'Ira', 'Martin', 'Ellerbrock', 'male', '1965-09-23',30,'955-555-0169', 'no', 'Ph.D', 800, '2022-01-03', 2),
	  ('422-85-0475', 'Herman', 'Perry', 'Hartwig', 'male', '1993-01-11',31 ,'818-555-0128','yes', 'Ph.D', 700, '2021-12-10', 4),
	  ('752-05-3696', 'Charles', NULL, 'Maxwell', 'male', '1965-05-15', 32,'314-555-0113', 'no', 'Ph.D', 750, '2021-12-10', 3),
	  ('807-13-9017', 'Clyde', 'Frank', 'Lugo', 'male', '1948-01-01', 33,'499-555-0125','yes', 'Ph.D', 740, '2021-12-10', 1),
	  ('711-06-1183', 'Theodore', 'Jesse', 'Michaels', 'male', '1981-04-08', 34,'753-555-0129', 'no', 'Ph.D', 720, '2021-12-10', 8),
	  ('419-78-1051', 'Calvin', 'Alex', 'Poland', 'male', '1959-02-02',35 ,'429-555-0137','yes', 'high school', 600, '2022-01-03', 11),
	  ('282-41-4685', 'August', 'Michael', 'Rettig', 'male', '1985-11-02', 36,'587-555-0115', 'no', 'high school', 660, '2021-12-10', 3),
	  ('888-90-4936', 'Harry', 'Alexander', 'Netz', 'male', '1965-09-13',37 ,'315-555-0144','yes', 'high school', 630,'2022-02-05', 1),
	  ('728-58-9206', 'Archie', 'Floyd', 'Creasey', 'male', '1957-01-01',38 ,'208-555-0114', 'no', 'high school', 780, '2022-01-03', 7),
	  ('178-60-1956', 'Thomas', 'Patrick', 'Martinez', 'male', '1967-10-01',39,'919-555-0140','yes', 'high school', 800, '2021-12-10', 7),
	  ('582-08-8098', 'Benjamin','Allen', 'Ray', 'male', '1957-10-20',40 ,'903-555-0145', 'no', 'high school', 770,'2022-02-05', 9);
INSERT dbo.CasePortal(customer_id, house_id, start_date, end_date, deductible_amount, limit)
VALUES(1, 23, '2008-01-11', '2009-01-10', 550, 300000),
      (2, 3, '2008-10-29','2009-10-28', 600, 100000),
	  (31, 4, '2009-06-19','2010-06-18', 700, 200000),
	  (11, 7,'2010-10-29','2011-10-28', 900, 500000),
	  (21, 8,'2011-01-04','2012-01-03', 1000, 300000),
	  (5, 9,'2015-02-06','2016-02-05', 1100, 350000),
	  (6, 10,'2016-03-10','2017-03-09', 600, 400000),
	  (21, 7,'2017-04-16','2018-04-15', 800, 250000),
	  (3, 8,'2018-05-30','2019-05-29', 1200, 300000),
	  (4, 10,'2019-06-30','2020-06-29', 1500, 350000),
	  (6, 12,'2015-07-10','2016-07-09', 1800, 390000),
	  (32, 9,'2013-08-11','2014-08-10', 2000, 320000),
	  (21, 4,'2012-09-22','2013-09-21', 1000, 100000),
	  (7, 9,'2016-10-20','2017-10-19', 1000, 200000),
	  (8, 16, '2008-01-11', '2009-01-10', 550, 300000),
      (9, 3, '2008-10-29','2009-10-28', 600, 100000),
	  (10, 4, '2009-06-19','2010-06-18', 700, 200000),
	  (13, 7,'2010-10-29','2011-10-28', 900, 570000),
	  (15, 8,'2011-01-04','2012-01-03', 1000, 350000),
	  (16, 9,'2015-02-06','2016-02-05', 1100, 330000),
	  (17, 10,'2016-03-10','2017-03-09', 600, 450000),
	  (18, 7,'2017-04-16','2018-04-15', 800, 250000),
	  (19, 8,'2018-05-30','2019-05-29', 1200, 300000),
	  (20, 10,'2019-06-30','2020-06-29', 1500, 350000),
	  (22, 12,'2015-07-10','2016-07-09', 1800, 390000),
	  (24, 9,'2013-08-11','2014-08-10', 2000, 380000),
	  (25, 4,'2012-09-22','2013-09-21', 1000, 100000),
	  (27, 9,'2016-10-20','2017-10-19', 1000, 200000),
	  (28, 4,'2018-11-23','2019-11-22', 1500, 150000),
	  (23, 6,'2019-12-24','2020-12-23', 2000, 120000),
	  (26, 4,'2010-01-26','2011-01-25', 500, 250000),
	  (29, 11,'2011-02-19','2012-02-18', 600, 100000),
	  (12, 11,'2012-03-17','2013-03-16', 700, 300000),
	  (30, 11,'2015-04-13','2016-04-12', 800, 350000),
	  (14, 23,'2016-05-11','2017-05-10', 1500, 400000),
	  (5, 3,'2018-06-08','2019-06-07', 1500, 500000),
	  (7, 9,'2015-07-13','2016-07-12', 1000, 300000),
	  (6, 4,'2016-08-19','2017-08-18', 1700, 200000),
	  (21, 9,'2019-09-13','2010-09-12', 1300, 100000),
	  (3, 3,'2011-10-23','2012-10-22', 1600, 300000);	 
INSERT dbo.CaseCoverage(case_id, coverage_id)
VALUES
	(11,2),(21,4),
	(3,6),(4,8),
	(5,10),(6,12),
	(7,1),(8,3),
	(9,5),(10,7),
	(11,9),(12,11),
	(13,13),(14,7),
	(15,8),(16,8),
	(17,9),(18,3),
	(19,1),(20,10),
	(21,5),(22,6),
	(23,2),(24,11),
	(25,13),(26,1),
	(21,7),(15,2),
	(16,13),
	(17,7),(18,6),
	(19,4),(20,11),
	(21,12),(22,9),
	(23,10),(24,7),
	(25,8),(26,9),
	(3,9),(4,11),
	(5,8),(6,9),
	(7,2),(8,7),
	(9,8),(10,11),
	(12,8),(12,12),
	(13,4),(14,8),
	(11,8),(21,13),
	(3,2),(4,7),
	(5,9),(6,7),
	(7,6),(8,1),
	(9,9);
INSERT dbo.ClaimHistory(house_id, customer_id, claim_date)
VALUES
    (5, 19, '2016-08-10'),
	(7, 10, '2007-02-20'),	
	(7, 4, '2009-04-18'),
	(5, 19, '2016-08-10'),
	(11, 10, '2007-02-20'),	
	(3, 4, '2019-04-18'),
	(16, 17, '2008-06-29'),
	(4, 19, '2008-07-11'),
	(22, 22, '2006-09-13'),
	(10, 24, '2010-10-18'),
	(21, 15, '2012-12-27'),
	(26, 17, '2019-03-13'),
	(23, 28, '2005-06-30'),
	(16, 39, '2011-01-21'),
    (7, 10, '2007-02-21'),	
	(13, 14, '2009-04-18'),
    (1, 25, '2013-12-15'),
	(16, 12, '2019-03-13'),
	(7, 28, '2017-06-25'),
	(15, 40, '2001-01-21'),
	(6, 18, '2018-06-01'),
	(4, 9, '2008-07-17'),
	(7, 25, '2006-09-23'),
	(2, 12, '2011-10-18');
INSERT dbo.Payment(claim_id, coverage_id, amount_paid, payment_status)
VALUES
	(1, 13, 80000, 'Pending'),
	(2, 2, 200000, 'Completed'),
	(13, 8, 300000, 'Completed'),
	(4, 9, 500000, 'Completed'),
	 (17, 11, 500000, 'Completed'),
	(18, 10, 100000, 'Pending'),
	(5, 12, 800000, 'Pending'),
	(7, 2, 50000, 'Completed'),
	(8, 9, 800000, 'Pending'),
	(19, 13, 200000, 'Pending'),
	(16, 5, 200000, 'Pending'),
	(19, 6, 900000, 'Completed'),
	(10, 10, 150000, 'Pending'),
	(11, 7, 900000, 'Completed'),
	(2, 1, 70000, 'Pending'),
	(13, 7, 950000, 'Completed'),
	(6, 3, 80000, 'Pending'),
	(14, 4, 70000, 'Pending'),
	(5, 3, 90000, 'Pending'),
	(20, 11, 70000, 'Pending'),
	(21, 3, 90000, 'Pending');


-- Part 5 Creat report views

-- 1) create view realted to customer_source for marketing
CREATE VIEW view_customer_source AS
     SELECT top 1000 cs.source_name, 
            count(distinct customer_id) as 'customer_count', 
            100*cast(count(distinct customer_id) as decimal)/(select cast(count(*) as decimal) from customerinfo) as 'Percentage'
     FROM customerinfo ci
     inner join CustomerSource cs
     on ci.customer_source_id = cs.customer_source_id
     group by cs.source_name
     order by count(distinct customer_id) desc;

select * from view_customer_source   

--2) create view for avg replacement price
CREATE VIEW view_avg_price_by_year_condition as
   select build_year, 
       case when [1] is null then '' else cast([1] as varchar(15)) end as '1',
       case when [2] is null then '' else cast([2] as varchar(15)) end as '2',
       case when [3] is null then '' else cast([3] as varchar(15)) end as '3',
       case when [4] is null then '' else cast([4] as varchar(15)) end as '4', 
       case when [5] is null then '' else cast([5] as varchar(15)) end as '5'
   from (select build_year, condition_level, replacement_cost
         from HouseInfo) as sourceTable
   pivot
      (avg(replacement_cost) for condition_level
                    in ([1],[2],[3],[4],[5]) ) as pivottable
                    
select * from view_avg_price_by_year_condition