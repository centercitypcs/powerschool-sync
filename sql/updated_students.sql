-- sqlfluff:dialect:ansi

WITH
ps AS (
    SELECT *
    FROM read_csv(
        getenv('PS_STUDENTS_INPUT_FILE'),
        delim = '\t',
        header = true
    )
),

gs AS (
    SELECT
        "customschemas.studentdata.student_number" AS student_number,
        "name.givenName" AS first_name,
        "name.familyName" AS last_name,
        orgunitpath AS org_unit,
        suspended
    FROM read_csv(
        getenv('GAPPS_STUDENTS_INPUT_FILE'),
        header = true
    )
)

SELECT
    ps.gapps_username,
    ps.first_name,
    ps.last_name,
    ps.org_unit,
    ps.school_code,
    ps.grade_level
FROM ps
    LEFT JOIN gs
        ON ps.student_number = gs.student_number
WHERE
    (
        ps.org_unit != gs.org_unit
        OR ps.last_name != gs.last_name
        OR ps.first_name != gs.first_name
    )
    AND NOT gs.suspended
ORDER BY
    ps.last_name;
