-- Query Student Enrollments from PowerSchool-SIS' Oracle Database

WITH all_enrollments AS (

    -- First get current/latest enrollment from Students table
    SELECT
        TO_CHAR(s.student_number) AS "Student ID",
        s.schoolid AS "Site ID",
        CASE TO_CHAR(s.entrydate, 'MM/dd/yyyy')
            WHEN '01/01/1900' THEN NULL
            ELSE TO_CHAR(s.entrydate, 'MM/dd/yyyy')
        END AS "Entry Date",
        CASE TO_CHAR(s.exitdate, 'MM/dd/yyyy')
            WHEN '01/01/1900' THEN NULL
            ELSE TO_CHAR(s.exitdate, 'MM/dd/yyyy')
        END AS "Leave Date",
        CASE s.grade_level
            WHEN -2 THEN 15
            WHEN -1 THEN 15
            WHEN 0 THEN 1
            WHEN 1 THEN 2
            WHEN 2 THEN 3
            WHEN 3 THEN 4
            WHEN 4 THEN 5
            WHEN 5 THEN 6
            WHEN 6 THEN 7
            WHEN 7 THEN 8
            WHEN 8 THEN 9
            WHEN 9 THEN 10
            WHEN 10 THEN 11
            WHEN 11 THEN 12
            WHEN 12 THEN 13
            WHEN 99 THEN 14
            ELSE s.grade_level
        END AS "Grade Level ID",
        :academic_year AS "Academic Year",
        NULL AS "Is Primary ADA"
    FROM
        (SELECT * FROM ps.students) s
        INNER JOIN schools sc ON s.schoolid = sc.school_number
    WHERE
        s.entrydate BETWEEN :first_day AND :last_day
        AND s.entrydate <= s.exitdate
        AND s.exitdate >= :earliest_exit
        AND s.schoolid IN (200, 300, 400, 500, 600, 700, 800)

    UNION

    -- Add *previous* enrollments for the current year that are stored in
    -- the reenrollments table

    SELECT
        TO_CHAR(s.student_number) AS "Student ID",
        e.schoolid AS "Site ID",
        CASE TO_CHAR(e.entrydate, 'MM/dd/yyyy')
            WHEN '01/01/1900' THEN NULL
            ELSE TO_CHAR(e.entrydate, 'MM/dd/yyyy')
        END AS "Entry Date",
        CASE TO_CHAR(e.exitdate, 'MM/dd/yyyy')
            WHEN '01/01/1900' THEN NULL
            ELSE TO_CHAR(e.exitdate, 'MM/dd/yyyy')
        END AS "Leave Date",
        CASE e.grade_level
            WHEN -2 THEN 15
            WHEN -1 THEN 15
            WHEN 0 THEN 1
            WHEN 1 THEN 2
            WHEN 2 THEN 3
            WHEN 3 THEN 4
            WHEN 4 THEN 5
            WHEN 5 THEN 6
            WHEN 6 THEN 7
            WHEN 7 THEN 8
            WHEN 8 THEN 9
            WHEN 9 THEN 10
            WHEN 10 THEN 11
            WHEN 11 THEN 12
            WHEN 12 THEN 13
            WHEN 99 THEN 14
            ELSE e.grade_level
        END AS "Grade Level ID",
        :academic_year AS "Academic Year",
        NULL AS "Is Primary ADA"
    FROM
        (SELECT * FROM ps.students) s
        INNER JOIN ps.reenrollments e ON s.id = e.studentid
        INNER JOIN schools sc ON e.schoolid = sc.school_number
    WHERE
        e.entrydate BETWEEN :first_day AND :last_day
        AND e.entrydate <= e.exitdate
        AND e.exitdate >= :earliest_exit
        AND e.schoolid IN (200, 300, 400, 500, 600, 700, 800)
)

SELECT *
FROM all_enrollments
ORDER BY
    "Student ID",
    "Entry Date"
