USE gym_db;

DROP VIEW IF EXISTS vw_member_class_counts;
DROP VIEW IF EXISTS vw_trainer_salary_rank;
DROP VIEW IF EXISTS vw_highly_active_members;

CREATE VIEW vw_member_class_counts AS
SELECT
    m.person_id AS member_id,
    p.first_name,
    p.last_name,
    COUNT(mce.session_id) AS total_enrollments,
    SUM(CASE WHEN mce.attendance_status = 'attended' THEN 1 ELSE 0 END) AS total_attended
FROM member m
JOIN person p ON p.person_id = m.person_id
LEFT JOIN member_class_enrollment mce ON mce.member_id = m.person_id
GROUP BY m.person_id, p.first_name, p.last_name;

CREATE VIEW vw_trainer_salary_rank AS
SELECT
    e.person_id AS employee_id,
    p.first_name,
    p.last_name,
    e.salary,
    RANK() OVER (ORDER BY e.salary DESC) AS salary_rank
FROM employee e
JOIN person p ON p.person_id = e.person_id
WHERE e.employee_role = 'trainer';

CREATE VIEW vw_highly_active_members AS
SELECT
    p.person_id AS member_id,
    p.first_name,
    p.last_name,
    (
      SELECT COUNT(*)
      FROM member_class_enrollment mce
      WHERE mce.member_id = p.person_id
    ) AS member_class_count
FROM person p
JOIN member m ON m.person_id = p.person_id
WHERE (
    SELECT COUNT(*)
    FROM member_class_enrollment mce2
    WHERE mce2.member_id = p.person_id
) > (
    SELECT AVG(class_count)
    FROM (
        SELECT COUNT(*) AS class_count
        FROM member_class_enrollment
        GROUP BY member_id
    ) x
);

DROP FUNCTION IF EXISTS fn_membership_days;
DROP FUNCTION IF EXISTS fn_member_attendance_rate;

DELIMITER //
CREATE FUNCTION fn_membership_days(p_member_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE days_active INT;
    SELECT DATEDIFF(CURDATE(), m.join_date) INTO days_active
    FROM member m
    WHERE m.person_id = p_member_id;
    RETURN COALESCE(days_active, 0);
END //
DELIMITER ;

DELIMITER //
CREATE FUNCTION fn_member_attendance_rate(p_member_id INT)
RETURNS DECIMAL(5,2)
READS SQL DATA
BEGIN
    DECLARE total_classes INT DEFAULT 0;
    DECLARE attended_classes INT DEFAULT 0;

    SELECT COUNT(*) INTO total_classes
    FROM member_class_enrollment
    WHERE member_id = p_member_id;

    SELECT COUNT(*) INTO attended_classes
    FROM member_class_enrollment
    WHERE member_id = p_member_id
      AND attendance_status = 'attended';

    IF total_classes = 0 THEN
        RETURN 0.00;
    END IF;

    RETURN ROUND((attended_classes / total_classes) * 100, 2);
END //
DELIMITER ;

DROP PROCEDURE IF EXISTS sp_register_member_for_session;
DROP PROCEDURE IF EXISTS sp_log_equipment_maintenance;

DELIMITER //
CREATE PROCEDURE sp_register_member_for_session(
    IN p_member_id INT,
    IN p_session_id INT
)
BEGIN
    DECLARE v_current_enrolled INT;
    DECLARE v_max_capacity INT;

    SELECT COUNT(*) INTO v_current_enrolled
    FROM member_class_enrollment
    WHERE session_id = p_session_id;

    SELECT fc.max_capacity INTO v_max_capacity
    FROM class_session cs
    JOIN fitness_class fc ON fc.class_id = cs.class_id
    WHERE cs.session_id = p_session_id;

    IF v_max_capacity IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Session does not exist.';
    END IF;

    IF v_current_enrolled >= v_max_capacity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Session is full.';
    END IF;

    INSERT INTO member_class_enrollment(member_id, session_id, attendance_status)
    VALUES (p_member_id, p_session_id, 'enrolled');
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE sp_log_equipment_maintenance(
    IN p_equipment_id INT,
    IN p_technician_id INT,
    IN p_notes VARCHAR(300)
)
BEGIN
    INSERT INTO maintenance_log(equipment_id, technician_id, maintenance_date, notes)
    VALUES (p_equipment_id, p_technician_id, NOW(), p_notes);
END //
DELIMITER ;

DROP TRIGGER IF EXISTS trg_class_session_validate;
DROP TRIGGER IF EXISTS trg_maintenance_updates_equipment;

DELIMITER //
CREATE TRIGGER trg_class_session_validate
BEFORE INSERT ON class_session
FOR EACH ROW
BEGIN
    DECLARE trainer_role VARCHAR(20);

    IF NEW.starts_at < NOW() THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot create class session in the past.';
    END IF;

    SELECT employee_role INTO trainer_role
    FROM employee
    WHERE person_id = NEW.trainer_id;

    IF trainer_role <> 'trainer' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Assigned employee is not a trainer.';
    END IF;
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER trg_maintenance_updates_equipment
AFTER INSERT ON maintenance_log
FOR EACH ROW
BEGIN
    UPDATE equipment
    SET status = 'maintenance'
    WHERE equipment_id = NEW.equipment_id;
END //
DELIMITER ;

-- Retrieval SQL for functionality

SELECT
    cs.session_id,
    fc.class_name,
    cs.starts_at,
    cs.ends_at,
    CONCAT(p.first_name, ' ', p.last_name) AS trainer_name
FROM class_session cs
JOIN fitness_class fc ON fc.class_id = cs.class_id
JOIN person p ON p.person_id = cs.trainer_id
WHERE DATE(cs.starts_at) = CURDATE()
ORDER BY cs.starts_at;

SELECT
    p.person_id AS member_id,
    CONCAT(p.first_name, ' ', p.last_name) AS member_name,
    fn_membership_days(p.person_id) AS membership_days,
    fn_member_attendance_rate(p.person_id) AS attendance_rate_pct
FROM person p
JOIN member m ON m.person_id = p.person_id
ORDER BY membership_days DESC
LIMIT 25;

SELECT *
FROM vw_highly_active_members
ORDER BY member_class_count DESC
LIMIT 20;

SELECT *
FROM vw_trainer_salary_rank
ORDER BY salary_rank;

SELECT *
FROM vw_member_class_counts
ORDER BY total_enrollments DESC
LIMIT 20;
