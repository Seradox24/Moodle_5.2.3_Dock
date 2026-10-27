<?php
// Build CLI arguments in-process so the administrative password is not a process argument.
$argv = ['/var/www/moodle/admin/cli/install_database.php', '--agree-license'];
foreach (['lang' => 'MOODLE_LANG', 'fullname' => 'MOODLE_SITE_FULLNAME',
          'shortname' => 'MOODLE_SITE_SHORTNAME', 'adminuser' => 'MOODLE_ADMIN_USER',
          'adminpass' => 'MOODLE_ADMIN_PASSWORD', 'adminemail' => 'MOODLE_ADMIN_EMAIL'] as $option => $key) {
    $default = $option === 'lang' ? 'es' : ($option === 'adminuser' ? 'admin' : '');
    $argv[] = '--' . $option . '=' . (getenv($key) ?: $default);
}
$argc = count($argv);
$_SERVER['argv'] = $argv;
$_SERVER['argc'] = $argc;
require '/var/www/moodle/admin/cli/install_database.php';
