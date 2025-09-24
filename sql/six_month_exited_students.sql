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
FROM gs
    LEFT JOIN ps
        ON gs.student_number = ps.student_number
WHERE
    ps.enroll_status != 0
    AND gs.suspended
    AND ps.exitdate < date_add(current_date, -183)
ORDER BY
    ps.gapps_username;
