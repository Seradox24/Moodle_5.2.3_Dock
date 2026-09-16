<?php
define('CLI_SCRIPT', true);
require '/var/www/moodle/config.php';
require '/var/www/moodle/public/version.php';

echo "Moodle: {$release}\nURL: {$CFG->wwwroot}\n";
$required = ['curl', 'dom', 'gd', 'intl', 'mbstring', 'pgsql', 'redis', 'soap', 'sodium', 'xml', 'zip'];
foreach ($required as $extension) {
    if (!extension_loaded($extension)) {
        fwrite(STDERR, "Missing PHP extension: {$extension}\n");
        exit(1);
    }
}
$DB->get_record('course', ['id' => SITEID], '*', MUST_EXIST);
if (!$CFG->disableupdateautodeploy) {
    foreach (['theme', 'mod', 'local', 'admin/tool'] as $directory) {
        if (!is_writable($CFG->dirroot . '/public/' . $directory)) {
            fwrite(STDERR, "Plugin directory is not writable: public/{$directory}\n");
            exit(1);
        }
    }
}
echo "Database, PHP extensions and plugin permissions OK.\n";
