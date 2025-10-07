# vim:ft=just ts=4 sw=4 et:
# useful constants

EDUPLUS_STUDENT_LICENSE_SKU := "1010310008"
EDUPLUS_STAFF_LICENSE_SKU := "1010310009"
DATA_DIR := env("DATA_DIR", justfile_directory() / "data")
ILLUMINATE_ILLUMINATE_EXPORTS_DIR := DATA_DIR / "illuminate_exports" / "illuminate"
ILLUMINATE_POWERSCHOOL_EXPORTS_DIR := DATA_DIR / "illuminate_exports" / "powerschool"
SQL_DIR := justfile_directory() / "sql"

# Set directory and  file paths for Google Student syncing. File paths are
# exported to the environment so they can be referenced within the queries
# executed by DuckDB.

GOOGLE_STUDENTS_INPUT_DIR := DATA_DIR / "google_students" / "input"
GOOGLE_STUDENTS_OUTPUT_DIR := DATA_DIR / "google_students" / "output"
export PS_STUDENTS_INPUT_FILE := GOOGLE_STUDENTS_INPUT_DIR / "ps_students.tsv"
export GAPPS_STUDENTS_INPUT_FILE := GOOGLE_STUDENTS_INPUT_DIR / "gapps_students_latest.csv"
export PASSWORDS_INPUT_FILE := GOOGLE_STUDENTS_INPUT_DIR / "passwords.txt"

# Set directory and file paths for Asset Panda Staff syncing. File paths are
# exported to the environment so they can be referenced within queries executed
# by DuckDB.

ASSET_PANDA_INPUT_DIR := DATA_DIR / "asset_panda" / "input"
ASSET_PANDA_OUTPUT_DIR := DATA_DIR / "asset_panda" / "output"
export PS_STAFF_FILE := ASSET_PANDA_INPUT_DIR / "ps_staff.csv"
export AP_STAFF_FILE := ASSET_PANDA_INPUT_DIR / "Staff_csv_list.csv"
export AP_UPDATE_FILE := ASSET_PANDA_OUTPUT_DIR / "asset_panda_staff_updates.csv"

# query parameters for Illuminate queries

ACADEMIC_YEAR := "academic_year=2025-2026"
FIRST_DAY := "first_day=01-JUL-2025"
LAST_DAY := "last_day=31-JUL-2026"
YEAR_ID := "year_id=35"
EARLIEST_EXIT := "earliest_exit=25-AUG-2025"

# run tools via "uvx"

RECORDS_EXE := "uvx --quiet --with oracledb --with docopt-ng records"
GAM_EXE := "uvx --quiet --from gam7 gam"

# list all targets
_default:
    @just --list --unsorted

# ensure DATA_DIRs exist
[group('infrastructure')]
[private]
ensure_data_dir:
    #!/usr/bin/env bash
    umask 0077
    mkdir -p {{ GOOGLE_STUDENTS_INPUT_DIR }}
    mkdir -p {{ GOOGLE_STUDENTS_OUTPUT_DIR }}
    mkdir -p {{ ILLUMINATE_POWERSCHOOL_EXPORTS_DIR }}
    mkdir -p {{ ILLUMINATE_ILLUMINATE_EXPORTS_DIR }}
    mkdir -p {{ ASSET_PANDA_INPUT_DIR }}
    mkdir -p {{ ASSET_PANDA_OUTPUT_DIR }}
    echo '*' > {{ DATA_DIR }}/.gitignore

# refresh list of passwords
[group('infrastructure')]
[group('target:google:students')]
[private]
refresh_password_list: ensure_data_dir
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Refreshing new password list" 1>&2
    pwgen -1s 8 500 |
        tr '[:upper:]' '[:lower:]' |
        tr 'oilq' '0119' > {{ GOOGLE_STUDENTS_INPUT_DIR }}/passwords.txt

# export students from Google Apps
[group('target:google:students')]
[private]
export_student_google_accounts: ensure_data_dir
    #!/usr/bin/env bash
    set -euo pipefail
    {{ GAM_EXE }} print users fields firstname,lastname,ou,suspended,externalids \
        schemas StudentData queries orgUnitPath=/Students,orgUnitPath=/OffBoarding/Students \
        >{{ GOOGLE_STUDENTS_INPUT_DIR }}/gapps_students_latest.csv

# export powerschool students
[group('target:google:students')]
[private]
export_powerschool_students: ensure_data_dir attach_vpn && detach_vpn
    #!/usr/bin/env bash
    OUTPUT_FILE="{{ GOOGLE_STUDENTS_INPUT_DIR }}/ps_students.tsv"
    echo "Querying to ${OUTPUT_FILE}" 1>&2
    {{ RECORDS_EXE }} {{ SQL_DIR }}/ps_students.sql tsv |
        sed -e 's/\r$//' -e '/^$/d' > "${OUTPUT_FILE}"

# query PowerSchool and Google to update local lists of student data
[group('target:google:students')]
generate_google_batches: export_powerschool_students export_student_google_accounts list_new_credentials list_new_students list_updated_students list_exited_students list_six_month_exited_students list_returned_students check_batch_counts
    @echo "done!"

# This recipe takes two parameters, one named USER_LIST, which
# is a set of users to act on, and GAM_COMMAND, which is the `gam`
# command to run across the {{USER_LIST}}.csv file

# run {{GAM_COMMAND}} with {{USER_LIST}}.csv
[group('target:google:students')]
[private]
run_gam_with_data USER_LIST GAM_COMMAND: ensure_data_dir
    #!/usr/bin/env bash
    set -euo pipefail
    user_list="{{ GOOGLE_STUDENTS_OUTPUT_DIR }}/{{ USER_LIST }}.csv"
    if test -s "${user_list}"; then
        {{ GAM_EXE }} csv "${user_list}" {{ GAM_COMMAND }}
    else
        echo No data in $(basename ${user_list}), gam command skipped.
    fi

# suspend exited students
[group('target:google:students')]
gam_process_exited_students: (run_gam_with_data "exited_students" "gam update user ~gapps_username suspended on gal off org /OffBoarding/Students")

# update orgUnit assignments and StudentData based on current PowerSchool data
[group('target:google:students')]
gam_process_updated_students: (run_gam_with_data "updated_students" "gam update user ~gapps_username org ~org_unit \
    firstname ~first_name lastname ~last_name \
    StudentData.school_code ~school_code \
    StudentData.grade_level ~grade_level")

# add Google accounts for new students
[group('target:google:students')]
gam_process_new_students: (run_gam_with_data "new_students" "gam create user ~gapps_username password ~gapps_password nohash \
    firstname ~firstname lastname ~lastname org ~ou_path \
    StudentData.student_number ~student_number \
    StudentData.school_code ~school_code \
    StudentData.grade_level ~grade_level")

# reactivate returned students
[group('target:google:students')]
gam_process_returned_students: (run_gam_with_data "returned_students" "gam update user ~email suspended off gal on org ~ou_path \
        password ~gapps_password nohash \
        StudentData.school_code ~school_code \
        StudentData.grade_level ~grade_level")

# delete former student exited more than 6 months ago
[group('target:google:students')]
gam_process_six_month_exited_students: (run_gam_with_data "six_month_exited_students" "gam delete user ~gapps_username")

# get count of users in batch files
[group('target:google:students')]
check_batch_counts: ensure_data_dir
    @echo "Results (Updates required of total lines > 1):"
    @wc -l {{ GOOGLE_STUDENTS_OUTPUT_DIR }}/*

# sync Google Workspace for Education Plus student licenses
[group('target:google:students')]
sync_student_workspace_licenses: export_student_google_accounts
    #!/usr/bin/env bash
    if [ "${LICENSE_ONLY_K_PLUS:-0}" = "1" ]; then
        echo "Generating k_plus_students to apply licenses to..." 1>&2
        GAPPS_STUDENTS_FILE="{{ GOOGLE_STUDENTS_INPUT_DIR }}/gapps_students_latest.csv" \
            duckdb -csv -f sql/k_plus_students.sql > "{{ GOOGLE_STUDENTS_OUTPUT_DIR }}/k_plus_students.csv"
        echo "Applying licenses to listed students..." 1>&2
        {{ GAM_EXE }} csvfile {{ GOOGLE_STUDENTS_OUTPUT_DIR }}/k_plus_students.csv:gapps_username \
            sync license {{ EDUPLUS_STUDENT_LICENSE_SKU }}
        printf "Cleaning up...\n"
        rm "{{ GOOGLE_STUDENTS_OUTPUT_DIR }}/k_plus_students.csv"
        printf "done.\n"
    else
        {{ GAM_EXE }} ou_and_children_ns /Students sync license {{ EDUPLUS_STUDENT_LICENSE_SKU }}
    fi

# Generate Google Workspace credentials for active students who don't have
# them. The output is a tab-seperated-value file that is imported into

# PowerSchool to update the credentials stored in the student's record.
[group('target:google:students')]
[private]
@list_new_credentials: ensure_data_dir refresh_password_list
    printf "Generating new_credentials..."
    duckdb -csv -separator $'\t' -f "{{ SQL_DIR }}/new_credentials.sql" > "{{ GOOGLE_STUDENTS_OUTPUT_DIR }}/new_credentials.tsv"
    printf "done.\n"

# This recipe takes a USER_LIST parameter which will determine the script to
# run against "ps_students" and "gapps_students_latest" data dumps to preduce an

# output file to pass to GAM.
[group('target:google:students')]
[private]
@student_updater USER_LIST: ensure_data_dir
    printf "Generating {{ USER_LIST }}..."
    duckdb -csv -f "{{ SQL_DIR }}/{{ USER_LIST }}.sql" > "{{ GOOGLE_STUDENTS_OUTPUT_DIR }}/{{ USER_LIST }}.csv"
    printf "done.\n"

# generate list of former students who's Google accounts are due for removal
[group('target:google:students')]
[private]
list_six_month_exited_students: (student_updater "six_month_exited_students")

# generate a list of updates for google_students
[group('target:google:students')]
[private]
list_updated_students: (student_updater "updated_students")

# generate a list of google_students to suspend
[group('target:google:students')]
[private]
list_exited_students: (student_updater "exited_students")

# generate a list of google_students to create
[group('target:google:students')]
[private]
list_new_students: (student_updater "new_students")

# generate a list of google_students to reactivate
[group('target:google:students')]
[private]
list_returned_students: (student_updater "returned_students")

# attach to the PowerSchool VPN
[group('infrastructure')]
[private]
attach_vpn:
    #!/usr/bin/env bash

    set -euo pipefail
    OPEN_CONNECT="$(which openconnect)"

    # if an existing connection is up, terminate it and exit
    PIDFILE="/var/run/openconnect.pid"
    if [[ -f "${PIDFILE}" ]]; then
        echo "VPN already attached!"
        exit
    fi

    echo "Attaching VPN"
    echo "${F5_PASSWORD}" | sudo "${OPEN_CONNECT}" \
        --background \
        --passwd-on-stdin \
        --pid-file="${PIDFILE}" \
        --protocol=f5 \
        --quiet \
        --user="${F5_USERNAME}" \
        "${F5_CONNECT_URL}" >/dev/null

# detach from the PowerSchool VPN
[group('infrastructure')]
[private]
detach_vpn:
    #!/usr/bin/env bash
    set -euo pipefail

    # if an existing connection is up, terminate it and exit
    PIDFILE="/var/run/openconnect.pid"
    if [[ ! -f "${PIDFILE}" ]]; then
        echo "No VPN attached!"
        exit
    fi

    echo "Detaching VPN"
    sudo /bin/kill -s TERM $(cat "${PIDFILE}")

# generate export files
[group('target:illuminate')]
generate_illuminate_exports: ensure_data_dir attach_vpn && detach_vpn compare_exports
    #!/usr/bin/env bash
    echo -n "Exporting courses... "
    {{ RECORDS_EXE }} {{ SQL_DIR }}/courses.sql tsv \
        > {{ ILLUMINATE_POWERSCHOOL_EXPORTS_DIR }}/courses.txt
    echo "done"

    echo -n "Exporting enrollment... "
    {{ RECORDS_EXE }} {{ SQL_DIR }}/enrollment.sql tsv \
        {{ ACADEMIC_YEAR }} {{ FIRST_DAY }} {{ LAST_DAY }} {{ EARLIEST_EXIT }} \
        > {{ ILLUMINATE_POWERSCHOOL_EXPORTS_DIR }}/enrollment.txt
    echo "done"

    echo -n "Exporting master schedule... "
    {{ RECORDS_EXE }} {{ SQL_DIR }}/mastschd.sql tsv \
        {{ YEAR_ID }} \
        > {{ ILLUMINATE_POWERSCHOOL_EXPORTS_DIR }}/mastschd.txt
    echo "done"

    echo -n "Exporting rosters... "
    {{ RECORDS_EXE }} {{ SQL_DIR }}/roster.sql tsv \
        {{ YEAR_ID }} {{ EARLIEST_EXIT }} \
        > {{ ILLUMINATE_POWERSCHOOL_EXPORTS_DIR }}/roster.txt
    echo "done"

    echo -n "Exporting student demographics... "
    {{ RECORDS_EXE }} {{ SQL_DIR }}/studemo.sql tsv \
        {{ ACADEMIC_YEAR }} {{ FIRST_DAY }} {{ EARLIEST_EXIT }} \
        > {{ ILLUMINATE_POWERSCHOOL_EXPORTS_DIR }}/studemo.txt
    echo "done"

    echo -n "Exporting users... "
    {{ RECORDS_EXE }} {{ SQL_DIR }}/users.sql tsv \
        > {{ ILLUMINATE_POWERSCHOOL_EXPORTS_DIR }}/users.txt
    echo "done"

    # set SED command (use gsed if available, else "sed")
    if $(command -v gsed > /dev/null); then
        SED="gsed"
    else
        SED="sed"
    fi

    # clean up terminating carraige returns and empty lines in exports
    for export_file in $(ls -1 {{ ILLUMINATE_POWERSCHOOL_EXPORTS_DIR }}); do
        ${SED} -i -e 's/\r$//' -e '/^$/d' {{ ILLUMINATE_POWERSCHOOL_EXPORTS_DIR }}/"${export_file}"
    done

# push export files to Illuminate SFTP server
[group('target:illuminate')]
push_exports: ensure_data_dir
    #!/usr/bin/env bash

    sftp -F "${ILLUMINATE_SSH_CONFIG_FILE}" -b - illuminate <<EOT
    lcd "{{ ILLUMINATE_POWERSCHOOL_EXPORTS_DIR }}"
    put *.txt
    exit
    EOT

# pull export files from Illuminate SFTP server
[group('target:illuminate')]
pull_exports: ensure_data_dir
    #!/usr/bin/env bash
    # Pull existing import files down from Illuminate SFTP
    # for comparison

    sftp -F "${ILLUMINATE_SSH_CONFIG_FILE}" -b - illuminate <<EOT
    lcd {{ ILLUMINATE_ILLUMINATE_EXPORTS_DIR }}
    get courses.txt
    get enrollment.txt
    get mastschd.txt
    get roster.txt
    get studemo.txt
    get users.txt
    exit
    EOT

# diff new exports with previous exports
[group('target:illuminate')]
diff_exports: ensure_data_dir
    @-delta {{ ILLUMINATE_ILLUMINATE_EXPORTS_DIR }} {{ ILLUMINATE_POWERSCHOOL_EXPORTS_DIR }}

# compare - pull previous exports and diff with new exports
[group('target:illuminate')]
compare_exports: ensure_data_dir pull_exports diff_exports

# sync Google Workspace for Education Plus staff licenses to unsuspended users in /Staff OU
[group('target:google:staff')]
@sync_staff_workspace_licenses:
    {{ GAM_EXE }} ou_and_children_ns /Staff sync license {{ EDUPLUS_STAFF_LICENSE_SKU }}

# export staff data from PowerSchool to CSV
[group('target:asset_panda:staff')]
[private]
@export_ps_staff: ensure_data_dir attach_vpn && detach_vpn
    echo "exporting PowerSchool staff to {{ PS_STAFF_FILE }} ... \c"
    {{ RECORDS_EXE }} {{ SQL_DIR }}/select_staff.sql csv | sed -e 's/\r$//' -e '/^$/d' >{{ PS_STAFF_FILE }}
    echo finished!

# generate a CSV of staff updates to import into AssetPanda
[group('target:asset_panda:staff')]
@generate_asset_panda_staff_updates: ensure_data_dir export_ps_staff
    printf "writing staff updates to {{ AP_UPDATE_FILE }}..."
    duckdb -csv -f "{{ SQL_DIR }}/export_asset_panda_staff.sql" > "{{ AP_UPDATE_FILE }}"
    printf "done.\n"

# sync staff AND student workspace licenses
[group('target:google:staff')]
[group('target:google:students')]
@sync_all_workspace_licenses: sync_student_workspace_licenses sync_staff_workspace_licenses
