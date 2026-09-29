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
if (getenv('MOODLE_REDIS_SESSIONS') === 'true') {
    if ($CFG->session_handler_class !== '\core\session\redis') {
        fwrite(STDERR, "Moodle is not configured to store sessions in Redis.\n");
        exit(1);
    }
    try {
        $redis = new Redis();
        $redis->connect($CFG->session_redis_host, $CFG->session_redis_port, 5);
        $redis->select($CFG->session_redis_database);
        if (!$redis->ping()) {
            throw new RuntimeException('Redis did not respond to PING.');
        }
        $redis->close();
    } catch (Throwable $error) {
        fwrite(STDERR, "Redis session store is unavailable: {$error->getMessage()}\n");
        exit(1);
    }
}
$DB->get_record('course', ['id' => SITEID], '*', MUST_EXIST);
// In Moodle 5.x dirroot points at the public code root where plugins live.
foreach (['theme', 'mod', 'local', 'admin/tool'] as $directory) {
    $writable = is_writable($CFG->dirroot . '/' . $directory);
    if ($writable === $CFG->disableupdateautodeploy) {
        fwrite(STDERR, "Plugin directory permissions do not match the selected mode: {$directory}\n");
        exit(1);
    }
}
echo "Database, PHP extensions and plugin permissions OK.\n";
