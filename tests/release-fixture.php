<?php
// Disposable integration projects only; retain content to verify restart/recovery.
define('CLI_SCRIPT', true);
require '/var/www/moodle/config.php';
require_once($CFG->dirroot . '/course/lib.php');
require_once($CFG->dirroot . '/course/modlib.php');

if (strpos(getenv('COMPOSE_TEST_PROJECT') ?: '', 'release-check-') !== 0) {
    throw new RuntimeException('This fixture requires a disposable release-check project.');
}
\core\session\manager::set_user(get_admin());
$shortname = 'release-integration';
$content = 'Persistent integration fixture for Moodle 5.3';
if (getenv('COMPOSE_TEST_MODE') === 'seed') {
    $course = create_course((object)[
        'category' => $DB->get_field_sql('SELECT MIN(id) FROM {course_categories}'),
        'fullname' => 'Release integration course',
        'shortname' => $shortname,
        'format' => 'topics',
    ]);
    add_moduleinfo((object)[
        'modulename' => 'page',
        'module' => $DB->get_field('modules', 'id', ['name' => 'page'], MUST_EXIST),
        'course' => $course->id,
        'section' => 0,
        'name' => 'Persistent release activity',
        'intro' => 'Integration fixture',
        'introformat' => FORMAT_HTML,
        'content' => $content,
        'contentformat' => FORMAT_HTML,
        'display' => 0,
        'visible' => 1,
    ], $course);
    get_file_storage()->create_file_from_string([
        'contextid' => context_course::instance($course->id)->id,
        'component' => 'course', 'filearea' => 'overviewfiles', 'itemid' => 0,
        'filepath' => '/', 'filename' => 'release-check.txt',
    ], $content);
}
$course = $DB->get_record('course', ['shortname' => $shortname], '*', MUST_EXIST);
$page = $DB->get_record('page', ['course' => $course->id], '*', MUST_EXIST);
if ($page->content !== $content) {
    throw new RuntimeException('Activity content differs.');
}
$file = get_file_storage()->get_file(context_course::instance($course->id)->id,
    'course', 'overviewfiles', 0, '/', 'release-check.txt');
if (!$file || $file->get_content() !== $content) {
    throw new RuntimeException('Stored file differs.');
}
echo "Course, activity and stored file verified.\n";
