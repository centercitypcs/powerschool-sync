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

SELECT ps.gapps_username
FROM ps
    LEFT JOIN gs
        ON ps.student_number = gs.student_number
WHERE
    ps.enroll_status != 0
    AND NOT gs.suspended;
