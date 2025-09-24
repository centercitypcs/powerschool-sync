-- Query Class/Section Roster Data from PowerSchool-SIS' Oracle Database
--
SELECT
    TO_CHAR(s.student_number) AS "Student ID",
    ABS(cc.sectionid) AS "Section ID",
    cc.schoolid AS "Site ID",
    cc.course_number AS "Course ID",
    t.teachernumber AS "User ID",
    CASE TO_CHAR(cc.dateenrolled, 'MM/dd/yyyy')
        WHEN '01/01/1900' THEN NULL
        ELSE TO_CHAR(cc.dateenrolled, 'MM/dd/yyyy')
    END AS "Entry Date",
    CASE TO_CHAR(cc.dateleft, 'MM/dd/yyyy')
        WHEN '01/01/1900' THEN NULL
        ELSE TO_CHAR(cc.dateleft, 'MM/dd/yyyy')
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
    TO_CHAR(trm.yearid + 1990)
    || '-'
    || TO_CHAR(trm.yearid + 1991) AS "Academic Year"
FROM
    (SELECT * FROM ps.students) s
    INNER JOIN ps.cc ON s.id = cc.studentid
    INNER JOIN ps.courses c ON cc.course_number = c.course_number
    INNER JOIN ps.teachers t ON cc.teacherid = t.id
    INNER JOIN schools sc ON cc.schoolid = sc.school_number
    INNER JOIN
        ps.terms trm
        ON trm.id = ABS(cc.termid) AND cc.schoolid = trm.schoolid
WHERE
    trm.yearid = :year_id
    AND cc.schoolid IN (200, 300, 400, 500, 600, 700, 800)
    AND s.exitdate >= :earliest_exit
ORDER BY
    s.id, cc.sectionid
