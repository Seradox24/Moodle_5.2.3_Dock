<?php
// Run as www-data in the app container. Tests the same APIs used by normal Moodle operations.
define('CLI_SCRIPT', true);
require '/var/www/moodle/config.php';
require_once($CFG->dirroot . '/user/lib.php');
require_once($CFG->dirroot . '/course/lib.php');

$token = 'permcheck' . bin2hex(random_bytes(5));
$userid = null;
$courseid = null;
$file = null;

try {
    $user = (object)[
        'username' => $token,
        'password' => 'Aa1!' . bin2hex(random_bytes(16)),
        'firstname' => 'Prueba',
        'lastname' => 'Temporal',
        'email' => $token . '@moodle.invalid',
        'auth' => 'manual',
        'confirmed' => 1,
        'mnethostid' => $CFG->mnet_localhost_id,
    ];
    $userid = user_create_user($user);
    if (!$DB->record_exists('user', ['id' => $userid, 'deleted' => 0])) {
        throw new RuntimeException('The temporary user was not saved.');
    }
    echo "User creation OK\n";

    $categoryid = $DB->get_field_sql('SELECT MIN(id) FROM {course_categories}');
    $course = create_course((object)[
        'category' => $categoryid,
        'fullname' => 'Curso temporal de permisos',
        'shortname' => $token,
        'summary' => 'Comprobación temporal de escritura de Moodle',
        'summaryformat' => FORMAT_HTML,
        'format' => 'topics',
    ]);
    $courseid = $course->id;
    if (!$DB->record_exists('course', ['id' => $courseid])) {
        throw new RuntimeException('The temporary course was not saved.');
    }
    echo "Course creation OK\n";

    $content = 'Temporary Moodle file storage check: ' . $token;
    $file = get_file_storage()->create_file_from_string([
        'contextid' => context_course::instance($courseid)->id,
        'component' => 'course',
        'filearea' => 'overviewfiles',
        'itemid' => 0,
        'filepath' => '/',
        'filename' => 'permission-check.txt',
        'userid' => $userid,
    ], $content);
    if ($file->get_content() !== $content) {
        throw new RuntimeException('The temporary file could not be read back.');
    }
    echo "File upload and readback OK\n";
} finally {
    if ($file !== null) {
        $file->delete();
    }
    if ($courseid !== null) {
        delete_course($courseid, false);
        if ($DB->record_exists('course', ['id' => $courseid])) {
            throw new RuntimeException('The temporary course was not removed.');
        }
    }
    if ($userid !== null) {
        user_delete_user($DB->get_record('user', ['id' => $userid]));
        if (!$DB->record_exists('user', ['id' => $userid, 'deleted' => 1])) {
            throw new RuntimeException('The temporary user was not deactivated.');
        }
    }
    echo "Temporary records cleaned up\n";
}
