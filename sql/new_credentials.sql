-- sqlfluff:dialect:duckdb

WITH
ps AS (
    SELECT
        student_number,
        row_number() OVER () AS row_num
    FROM
        read_csv(
            getenv('PS_STUDENTS_INPUT_FILE'),
            header = TRUE
        )
    WHERE
        enroll_status = 0
        AND gapps_username IS NULL
),

pw AS (
    SELECT
        gapps_password,
        row_number() OVER () AS row_num
    FROM read_csv(
        getenv('PASSWORDS_INPUT_FILE'),
        header = FALSE,
        columns = { 'gapps_password' :'VARCHAR' }
    )
)

SELECT
    ps.student_number,
    pw.gapps_password,
    printf('st%d@centercitypcs.org', ps.student_number) AS gapps_username
FROM ps
    LEFT JOIN pw
        ON ps.row_num = pw.row_num;
