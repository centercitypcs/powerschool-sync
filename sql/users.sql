-- Query Users/Teacher Data from PowerSchool-SIS' Oracle Database
-- sqlfluff:rules:references.quoting:ignore_words:Username

SELECT DISTINCT
    t.teachernumber AS "Local User ID",
    t.last_name AS "Last Name",
    t.first_name AS "First Name",
    t.email_addr AS "Email Address",
    REPLACE(t.email_addr, '@centercitypcs.org', '') AS "Username",
    t.title AS "Job Title"
FROM
    (SELECT * FROM ps.schoolstaff) ss
    INNER JOIN ps.users t ON (ss.users_dcid = t.dcid)
WHERE
    ss.status = 1
    AND ss.staffstatus IN (1, 2, 4)
    AND t.email_addr IS NOT NULL
    AND ss.schoolid IN (200, 300, 400, 500, 600, 700, 800)
ORDER BY
    t.teachernumber
