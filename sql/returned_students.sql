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
        suspended
    FROM read_csv(
        getenv('GAPPS_STUDENTS_INPUT_FILE'),
        header = true
    )
)

SELECT
    ps.gapps_username AS email,
    ps.gapps_password,
    ps.org_unit AS ou_path,
    ps.school_code,
    ps.grade_level
FROM ps
    LEFT JOIN gs
        ON ps.student_number = gs.student_number
WHERE
    ps.enroll_status = 0
    AND gs.suspended
ORDER BY
    ps.gapps_username;
