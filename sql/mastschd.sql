-- Write master schedule data.
-- sqlfluff:rules:references.quoting:ignore_words:Period

SELECT
    sections.id AS "Section ID",
    sections.schoolid AS "Site ID",
    CASE
        WHEN terms.abbreviation LIKE '%-%' THEN 'Y'
        ELSE terms.abbreviation
    END AS "Term Name",
    sections.course_number AS "Course ID",
    users.teachernumber AS "User ID",
    CASE
        WHEN
            (sections.expression IS NULL OR sections.expression = '')
            THEN 'Unknown'
        ELSE sections.expression
    END AS "Period",
    TO_CHAR(terms.yearid + 1990)
    || '-'
    || TO_CHAR(terms.yearid + 1991) AS "Academic Year"

FROM sections
    LEFT JOIN sectionteacher ON sections.id = sectionteacher.sectionid
    INNER JOIN
        terms
        ON (sections.termid = terms.id AND sections.schoolid = terms.schoolid)
    INNER JOIN schoolstaff ON sectionteacher.teacherid = schoolstaff.id
    INNER JOIN users ON schoolstaff.users_dcid = users.dcid

WHERE
    terms.yearid = :year_id
    AND sections.schoolid IN (200, 300, 400, 500, 600, 700, 800)

ORDER BY
    sections.id,
    users.teachernumber
