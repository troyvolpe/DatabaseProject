DROP DATABASE IF EXISTS gym_db;
CREATE DATABASE gym_db;
USE gym_db;

CREATE TABLE person (
    person_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE member (
    person_id INT PRIMARY KEY,
    join_date DATE NOT NULL,
    status ENUM('active', 'paused', 'cancelled') NOT NULL DEFAULT 'active',
    CONSTRAINT fk_member_person
        FOREIGN KEY (person_id) REFERENCES person(person_id)
        ON DELETE CASCADE
);

CREATE TABLE employee (
    person_id INT PRIMARY KEY,
    employee_role ENUM('trainer', 'manager', 'maintenance') NOT NULL,
    hire_date DATE NOT NULL,
    salary DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_employee_person
        FOREIGN KEY (person_id) REFERENCES person(person_id)
        ON DELETE CASCADE
);

CREATE TABLE membership_plan (
    plan_id INT AUTO_INCREMENT PRIMARY KEY,
    plan_name VARCHAR(60) NOT NULL UNIQUE,
    monthly_fee DECIMAL(8,2) NOT NULL,
    contract_months INT NOT NULL
);

CREATE TABLE member_membership (
    member_membership_id INT AUTO_INCREMENT PRIMARY KEY,
    member_id INT NOT NULL,
    plan_id INT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_membership_dates CHECK (end_date >= start_date),
    CONSTRAINT fk_member_membership_member
        FOREIGN KEY (member_id) REFERENCES member(person_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_member_membership_plan
        FOREIGN KEY (plan_id) REFERENCES membership_plan(plan_id)
);

CREATE TABLE fitness_class (
    class_id INT AUTO_INCREMENT PRIMARY KEY,
    class_name VARCHAR(80) NOT NULL UNIQUE,
    duration_minutes INT NOT NULL,
    max_capacity INT NOT NULL,
    CONSTRAINT chk_capacity CHECK (max_capacity > 0)
);

CREATE TABLE class_session (
    session_id INT AUTO_INCREMENT PRIMARY KEY,
    class_id INT NOT NULL,
    trainer_id INT NOT NULL,
    starts_at DATETIME NOT NULL,
    ends_at DATETIME NOT NULL,
    CONSTRAINT chk_session_time CHECK (ends_at > starts_at),
    CONSTRAINT fk_class_session_class
        FOREIGN KEY (class_id) REFERENCES fitness_class(class_id),
    CONSTRAINT fk_class_session_trainer
        FOREIGN KEY (trainer_id) REFERENCES employee(person_id)
);

CREATE TABLE member_class_enrollment (
    member_id INT NOT NULL,
    session_id INT NOT NULL,
    enrolled_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    attendance_status ENUM('enrolled', 'attended', 'no_show') NOT NULL DEFAULT 'enrolled',
    PRIMARY KEY (member_id, session_id),
    CONSTRAINT fk_member_class_enrollment_member
        FOREIGN KEY (member_id) REFERENCES member(person_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_member_class_enrollment_session
        FOREIGN KEY (session_id) REFERENCES class_session(session_id)
        ON DELETE CASCADE
);

CREATE TABLE specialty (
    specialty_id INT AUTO_INCREMENT PRIMARY KEY,
    specialty_name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE trainer_specialty (
    trainer_id INT NOT NULL,
    specialty_id INT NOT NULL,
    certified_on DATE NOT NULL,
    PRIMARY KEY (trainer_id, specialty_id),
    CONSTRAINT fk_trainer_specialty_trainer
        FOREIGN KEY (trainer_id) REFERENCES employee(person_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_trainer_specialty_specialty
        FOREIGN KEY (specialty_id) REFERENCES specialty(specialty_id)
);

CREATE TABLE goal (
    goal_id INT AUTO_INCREMENT PRIMARY KEY,
    goal_name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE member_goal (
    member_id INT NOT NULL,
    goal_id INT NOT NULL,
    set_on DATE NOT NULL,
    target_date DATE,
    achieved_on DATE,
    PRIMARY KEY (member_id, goal_id),
    CONSTRAINT fk_member_goal_member
        FOREIGN KEY (member_id) REFERENCES member(person_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_member_goal_goal
        FOREIGN KEY (goal_id) REFERENCES goal(goal_id)
);

CREATE TABLE equipment (
    equipment_id INT AUTO_INCREMENT PRIMARY KEY,
    equipment_name VARCHAR(80) NOT NULL,
    status ENUM('active', 'maintenance', 'retired') NOT NULL DEFAULT 'active'
);

CREATE TABLE maintenance_log (
    maintenance_id INT AUTO_INCREMENT PRIMARY KEY,
    equipment_id INT NOT NULL,
    technician_id INT NOT NULL,
    maintenance_date DATETIME NOT NULL,
    notes VARCHAR(300),
    CONSTRAINT fk_maintenance_log_equipment
        FOREIGN KEY (equipment_id) REFERENCES equipment(equipment_id),
    CONSTRAINT fk_maintenance_log_technician
        FOREIGN KEY (technician_id) REFERENCES employee(person_id)
);

CREATE INDEX idx_person_name ON person(last_name, first_name);
CREATE INDEX idx_session_start ON class_session(starts_at);
CREATE INDEX idx_session_trainer_start ON class_session(trainer_id, starts_at);
CREATE INDEX idx_enrollment_session_status ON member_class_enrollment(session_id, attendance_status);
CREATE INDEX idx_membership_member_active ON member_membership(member_id, is_active);

DELIMITER //
CREATE PROCEDURE sp_seed_test_data(IN p_member_count INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE employee_count INT DEFAULT 20;
    DECLARE current_employee_id INT;
    DECLARE current_member_id INT;

    INSERT INTO membership_plan (plan_name, monthly_fee, contract_months)
    VALUES ('Basic-12', 29.99, 12), ('Standard-12', 49.99, 12), ('Premium-12', 79.99, 12);

    INSERT INTO specialty (specialty_name) VALUES ('HIIT'), ('Yoga'), ('Strength');
    INSERT INTO goal (goal_name) VALUES ('Weight Loss'), ('Muscle Gain'), ('Endurance');
    INSERT INTO fitness_class (class_name, duration_minutes, max_capacity)
    VALUES ('Morning HIIT', 45, 24), ('Lunch Yoga', 60, 30), ('Strength 101', 50, 20);
    INSERT INTO equipment (equipment_name, status)
    VALUES ('Treadmill A1', 'active'), ('Row Machine R1', 'active'), ('Squat Rack S1', 'active');

    WHILE i <= employee_count DO
        INSERT INTO person (first_name, last_name, email)
        VALUES (CONCAT('Emp', i), 'Staff', CONCAT('employee', i, '@gym.local'));
        SET current_employee_id = LAST_INSERT_ID();

        INSERT INTO employee (person_id, employee_role, hire_date, salary)
        VALUES (
            current_employee_id,
            CASE WHEN i <= 14 THEN 'trainer' WHEN i <= 17 THEN 'maintenance' ELSE 'manager' END,
            DATE_SUB(CURDATE(), INTERVAL (300 + i) DAY),
            42000 + (i * 1000)
        );

        IF i <= 14 THEN
            INSERT INTO trainer_specialty (trainer_id, specialty_id, certified_on)
            VALUES (current_employee_id, ((i - 1) MOD 3) + 1, DATE_SUB(CURDATE(), INTERVAL 100 DAY));
        END IF;
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= p_member_count DO
        INSERT INTO person (first_name, last_name, email)
        VALUES (CONCAT('Member', i), CONCAT('User', i), CONCAT('member', i, '@gym.local'));
        SET current_member_id = LAST_INSERT_ID();

        INSERT INTO member (person_id, join_date, status)
        VALUES (current_member_id, DATE_SUB(CURDATE(), INTERVAL (i MOD 365) DAY), CASE WHEN i MOD 25 = 0 THEN 'paused' ELSE 'active' END);

        INSERT INTO member_membership (member_id, plan_id, start_date, end_date, is_active)
        VALUES (current_member_id, ((i - 1) MOD 3) + 1, DATE_SUB(CURDATE(), INTERVAL 45 DAY), DATE_ADD(CURDATE(), INTERVAL 320 DAY), TRUE);

        INSERT INTO member_goal (member_id, goal_id, set_on, target_date)
        VALUES (current_member_id, ((i - 1) MOD 3) + 1, DATE_SUB(CURDATE(), INTERVAL 20 DAY), DATE_ADD(CURDATE(), INTERVAL 120 DAY));

        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= p_member_count DO
        INSERT INTO class_session (class_id, trainer_id, starts_at, ends_at)
        VALUES (
            ((i - 1) MOD 3) + 1,
            ((i - 1) MOD 14) + 1,
            DATE_ADD(DATE_ADD(CURDATE(), INTERVAL (i MOD 21) DAY), INTERVAL (6 + (i MOD 8)) HOUR),
            DATE_ADD(DATE_ADD(DATE_ADD(CURDATE(), INTERVAL (i MOD 21) DAY), INTERVAL (6 + (i MOD 8)) HOUR), INTERVAL 45 MINUTE)
        );

        INSERT INTO member_class_enrollment (member_id, session_id, attendance_status)
        VALUES (i + employee_count, i, CASE WHEN i MOD 4 = 0 THEN 'attended' ELSE 'enrolled' END);

        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

CALL sp_seed_test_data(220);
