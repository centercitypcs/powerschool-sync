-- Query "courses" from PowerSchool-SIS' Oracle Database

SELECT DISTINCT
    c.course_number AS "School Course ID",
    c.course_name AS "Long Name",
    c.course_name AS "Short Name",
    15 AS "Start Grade Level ID",
    13 AS "End Grade Level ID"
FROM (SELECT * FROM ps.courses) c
ORDER BY
    c.course_number
