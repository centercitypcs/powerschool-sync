-- sqlfluff:dialect:duckdb
-- sqlfluff:rules:capitalisation.keywords:capitalisation_policy:upper

WITH
ps_staff AS (
    SELECT *
    FROM
        read_csv(
            getenv('PS_STAFF_FILE'),
            header = true
        )
    WHERE
        email IS NOT null
        AND email LIKE '%@centercitypcs.org'
),

ap_staff AS (
    SELECT *
    FROM
        read_csv(
            getenv('AP_STAFF_FILE'),
            header = true
        )
    WHERE
        status = 'Active'
),

updated_staff AS (
    SELECT
        ps_staff."Employee ID",
        ps_staff.email,
        ps_staff."Last Name",
        ps_staff."First Name",
        ps_staff."Job Title",
        ps_staff.location,
        ap_staff.status
    FROM ps_staff
        INNER JOIN ap_staff ON ps_staff."Employee ID" = ap_staff."Employee ID"
    WHERE
        ps_staff.email != ap_staff.email
        OR ps_staff."Last Name" != ap_staff."Last Name"
        OR ps_staff."First Name" != ap_staff."First Name"
        OR ps_staff."Job Title" != ap_staff."Job Title"
        OR ps_staff.location != ap_staff.location
),

new_staff AS (
    SELECT
        ps_staff."Employee ID",
        ps_staff.email,
        ps_staff."Last Name",
        ps_staff."First Name",
        ps_staff."Job Title",
        ps_staff.location,
        'Active' AS status
    FROM ps_staff
        LEFT JOIN ap_staff ON ps_staff."Employee ID" = ap_staff."Employee ID"
    WHERE
        ap_staff.email IS null
),

departed_staff AS (
    SELECT
        ap_staff."Employee ID",
        ap_staff.email,
        ap_staff."Last Name",
        ap_staff."First Name",
        ap_staff."Job Title",
        ap_staff.location,
        'Inactive' AS status
    FROM ap_staff
        LEFT JOIN ps_staff ON ap_staff."Employee ID" = ps_staff."Employee ID"
    WHERE
        ps_staff.email IS null
)

SELECT * FROM updated_staff
UNION
SELECT * FROM new_staff
UNION
SELECT * FROM departed_staff;
