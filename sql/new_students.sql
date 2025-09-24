-- sqlfluff:dialect:ansi

WITH
ps AS (
    SELECT *
    FROM read_csv(
        getenv('PS_STUDENTS_INPUT_FILE'),
        header = true
    )
),

gs AS (
    SELECT "customschemas.studentdata.student_number" AS student_number
    FROM read_csv(
        getenv('GAPPS_STUDENTS_INPUT_FILE'),
        header = true
    )
)

SELECT
    ps.gapps_username,
    ps.gapps_password,
    ps.first_name AS firstname,
    ps.last_name AS lastname,
    ps.org_unit AS ou_path,
    ps.student_number,
    ps.school_code,
    ps.grade_level
FROM ps
    LEFT JOIN gs
        ON ps.student_number = gs.student_number
WHERE
    gs.student_number IS null
    AND ps.gapps_username IS NOT null
    AND ps.gapps_password IS NOT null
    AND ps.enroll_status = 0
ORDER BY
    ps.gapps_username;
