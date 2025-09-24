-- ps_active_students.sql
-- sqlfluff:dialect:oracle
--
-- Query all students in PowerSchool and transform PowerSchool
-- codes to more human mnemonics. The main query is also wrapped
-- in a CTE so we can use calculated values to generate the org_unit
-- column.

WITH students_q AS (
    SELECT
        TO_CHAR(students.student_number) AS student_number,
        CASE students.schoolid
            WHEN 200 THEN 'BRI'
            WHEN 300 THEN 'CAP'
            WHEN 400 THEN 'CON'
            WHEN 500 THEN 'PET'
            WHEN 600 THEN 'SHA'
            WHEN 700 THEN 'TRI'
        END AS school_code,
        students.grade_level,
        CASE students.grade_level
            WHEN -2 THEN 'PK3'
            WHEN -1 THEN 'PK4'
            WHEN 0 THEN 'K'
            WHEN 99 THEN 'MAT'
            ELSE TO_CHAR(students.grade_level)
        END AS grade_code,
        students.last_name,
        students.first_name,
        u_def_ext_students.gapps_username,
        u_def_ext_students.gapps_password,
        TO_CHAR(students.enroll_status) AS enroll_status,
        TO_CHAR(students.exitdate, 'YYYY-MM-DD') AS exitdate,
        TO_CHAR(students.entrydate, 'YYYY-MM-DD') AS entrydate
    FROM students
        INNER JOIN schools ON students.schoolid = schools.school_number
        LEFT JOIN
            u_def_ext_students
            ON students.dcid = u_def_ext_students.studentsdcid
    WHERE students.schoolid IN (200, 300, 400, 500, 600, 700)
)

SELECT
    student_number,
    school_code,
    grade_level,
    grade_code,
    last_name,
    first_name,
    gapps_username,
    gapps_password,
    enroll_status,
    exitdate,
    entrydate,
    '/Students/' || school_code || '/' || grade_code AS org_unit
FROM students_q
ORDER BY student_number
