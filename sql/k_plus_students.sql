-- sqlfluff:core:dialect:duckdb

SELECT primaryemail AS gapps_username
FROM
    read_csv(
        getenv('GAPPS_STUDENTS_FILE'),
        header = true
    )
WHERE
    NOT suspended
    AND "customschemas.studentdata.grade_level" >= -1 -- noqa: RF05
ORDER BY
    gapps_username;
