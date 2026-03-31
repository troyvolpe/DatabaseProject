-- 1. Supertype Table
CREATE TABLE User (
    UserID INT AUTO_INCREMENT PRIMARY KEY,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    UserType ENUM('Member', 'Employee') NOT NULL
);

-- 2. Subtype: Member
CREATE TABLE Member (
    MemberID INT PRIMARY KEY,
    MembershipTier VARCHAR(20) NOT NULL,
    JoinDate DATE NOT NULL,
    FOREIGN KEY (MemberID) REFERENCES User(UserID) ON DELETE CASCADE
);

-- 3. Subtype: Employee
CREATE TABLE Employee (
    EmployeeID INT PRIMARY KEY,
    Role VARCHAR(50) NOT NULL,
    HireDate DATE NOT NULL,
    Salary DECIMAL(10,2),
    FOREIGN KEY (EmployeeID) REFERENCES User(UserID) ON DELETE CASCADE
);

-- 4. Class Entity
CREATE TABLE Class (
    ClassID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    Description TEXT,
    MaxCapacity INT NOT NULL
);

-- 5. Schedule Entity (1:M from Class)
CREATE TABLE Schedule (
    ScheduleID INT AUTO_INCREMENT PRIMARY KEY,
    ClassID INT NOT NULL,
    EmployeeID INT NOT NULL, -- The Trainer
    StartTime DATETIME NOT NULL,
    EndTime DATETIME NOT NULL,
    FOREIGN KEY (ClassID) REFERENCES Class(ClassID),
    FOREIGN KEY (EmployeeID) REFERENCES Employee(EmployeeID)
);

-- 6. Bridge 1: Class_Roster (M:M Member and Schedule)
CREATE TABLE Class_Roster (
    MemberID INT NOT NULL,
    ScheduleID INT NOT NULL,
    EnrollmentDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (MemberID, ScheduleID),
    FOREIGN KEY (MemberID) REFERENCES Member(MemberID),
    FOREIGN KEY (ScheduleID) REFERENCES Schedule(ScheduleID)
);

-- 7. Bridge 2: Training_Session (M:M Member and Employee/Trainer)
CREATE TABLE Training_Session (
    SessionID INT AUTO_INCREMENT PRIMARY KEY,
    MemberID INT NOT NULL,
    EmployeeID INT NOT NULL,
    SessionDate DATETIME NOT NULL,
    Notes TEXT,
    FOREIGN KEY (MemberID) REFERENCES Member(MemberID),
    FOREIGN KEY (EmployeeID) REFERENCES Employee(EmployeeID)
);

-- 8. Equipment Entity
CREATE TABLE Equipment (
    EquipID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    PurchaseDate DATE NOT NULL,
    Status ENUM('Active', 'Maintenance', 'Retired') DEFAULT 'Active'
);

-- 9. Bridge 3: Maintenance_Log (M:M Equipment and Employee/Staff)
CREATE TABLE Maintenance_Log (
    LogID INT AUTO_INCREMENT PRIMARY KEY,
    EquipID INT NOT NULL,
    EmployeeID INT NOT NULL,
    MaintenanceDate DATETIME NOT NULL,
    Description TEXT,
    FOREIGN KEY (EquipID) REFERENCES Equipment(EquipID),
    FOREIGN KEY (EmployeeID) REFERENCES Employee(EmployeeID)
);

-- View 1: Aggregate Query (member class counts)
CREATE VIEW vw_MemberClassCounts AS
SELECT 
    u.FirstName, 
    u.LastName, 
    COUNT(cr.ScheduleID) AS TotalClassesTaken
FROM User u
JOIN Member m ON u.UserID = m.MemberID
LEFT JOIN Class_Roster cr ON m.MemberID = cr.MemberID
GROUP BY u.UserID, u.FirstName, u.LastName;

-- Window Function: Employee Salary Rankings by Role
CREATE VIEW vw_EmployeeSalaryRank AS
SELECT 
    u.FirstName, 
    u.LastName, 
    e.Role, 
    e.Salary,
    RANK() OVER(PARTITION BY e.Role ORDER BY e.Salary DESC) as SalaryRank
FROM User u
JOIN Employee e ON u.UserID = e.EmployeeID;

-- View 3: Correlated Subquery (Highly Active Members, more classes than average)
CREATE VIEW vw_HighlyActiveMembers AS
SELECT 
    u.FirstName, 
    u.LastName
FROM User u
JOIN Member m ON u.UserID = m.MemberID
WHERE (
    SELECT COUNT(*) 
    FROM Class_Roster cr 
    WHERE cr.MemberID = m.MemberID
) > (
    SELECT AVG(ClassCount) 
    FROM (SELECT COUNT(*) as ClassCount FROM Class_Roster GROUP BY MemberID) as Sub
);

-- Data Retrieval Requirements & SQL
SELECT 
    c.Name AS ClassName, 
    s.StartTime, 
    s.EndTime, 
    u.FirstName AS TrainerName
FROM Schedule s
JOIN Class c ON s.ClassID = c.ClassID
JOIN Employee e ON s.EmployeeID = e.EmployeeID
JOIN User u ON e.EmployeeID = u.UserID
WHERE DATE(s.StartTime) = '2026-04-01';

DELIMITER //
CREATE FUNCTION GetMembershipDays(p_MemberID INT) 
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE days_active INT;
    SELECT DATEDIFF(CURRENT_DATE, JoinDate) INTO days_active 
    FROM Member 
    WHERE MemberID = p_MemberID;
    RETURN days_active;
END //
DELIMITER ;

-- Database Procedures and Functions
-- Function: Calculate Membership Duration
DELIMITER //
CREATE PROCEDURE RegisterMember(IN p_MemberID INT, IN p_ScheduleID INT)
BEGIN
    DECLARE current_count INT;
    DECLARE max_cap INT;
    
    -- Get current enrollment and max capacity
    SELECT COUNT(*) INTO current_count FROM Class_Roster WHERE ScheduleID = p_ScheduleID;
    SELECT c.MaxCapacity INTO max_cap FROM Schedule s JOIN Class c ON s.ClassID = c.ClassID WHERE s.ScheduleID = p_ScheduleID;
    
    IF current_count < max_cap THEN
        INSERT INTO Class_Roster (MemberID, ScheduleID) VALUES (p_MemberID, p_ScheduleID);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Class is at full capacity.';
    END IF;
END //
DELIMITER ;

-- Procedure: register for a class safely
DELIMITER //
CREATE PROCEDURE RegisterMember(IN p_MemberID INT, IN p_ScheduleID INT)
BEGIN
    DECLARE current_count INT;
    DECLARE max_cap INT;
    
    -- Get current enrollment and max capacity
    SELECT COUNT(*) INTO current_count FROM Class_Roster WHERE ScheduleID = p_ScheduleID;
    SELECT c.MaxCapacity INTO max_cap FROM Schedule s JOIN Class c ON s.ClassID = c.ClassID WHERE s.ScheduleID = p_ScheduleID;
    
    IF current_count < max_cap THEN
        INSERT INTO Class_Roster (MemberID, ScheduleID) VALUES (p_MemberID, p_ScheduleID);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Class is at full capacity.';
    END IF;
END //
DELIMITER ;

-- Triggers
-- Trigger 1: Data validation (Prevent backdating schedules)
DELIMITER //
CREATE TRIGGER trg_BeforeInsertSchedule
BEFORE INSERT ON Schedule
FOR EACH ROW
BEGIN
    IF NEW.StartTime < CURRENT_TIMESTAMP THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot schedule a class in the past.';
    END IF;
END //
DELIMITER ;

-- Trigger 2: State Automation (Update equipment status)
DELIMITER //
CREATE TRIGGER trg_AfterInsertMaintenance
AFTER INSERT ON Maintenance_Log
FOR EACH ROW
BEGIN
    UPDATE Equipment 
    SET Status = 'Maintenance' 
    WHERE EquipID = NEW.EquipID;
END //
DELIMITER ;


-- Indexes:
-- Index 1: Optimize searching users by email (frequent for logins/lookups)
CREATE INDEX idx_user_email ON User(Email);

-- Index 2: Optimize querying the schedule by date (frequent for daily timetable rendering)
CREATE INDEX idx_schedule_time ON Schedule(StartTime);
