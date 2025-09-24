-- Query Student Demographic Data from PowerSchool-SIS' Oracle Database
-- sqlfluff:rules:references.quoting:ignore_words:Gender

SELECT
    TO_CHAR(s.student_number) AS "Import Student ID",
    s.last_name AS "Student Last Name",
    s.first_name AS "Student First Name",
    s.middle_name AS "Student Middle Name",
    CASE TO_CHAR(s.dob, 'MM/dd/yyyy')
        WHEN '01/01/1900' THEN NULL
        ELSE TO_CHAR(s.dob, 'MM/dd/yyyy')
    END AS "Birth Date",
    UPPER(s.gender) AS "Gender",
    :academic_year AS "Academic Year"
FROM
    (SELECT * FROM ps.students) s
WHERE
    s.entrydate >= :first_day
    AND s.exitdate >= :earliest_exit
    AND s.schoolid IN (200, 300, 400, 500, 600, 700, 800)
ORDER BY
    s.student_number
