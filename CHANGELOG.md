# 1.1.0
- Added a new `rename` event which fires when a file is renamed
- Added a new method `fs_watcher.stopAll` which stops all running watchers

# 1.0.2
- Made the callback automatically stop the watcher if a truthy value is returned

# 1.0.1
- Fix very minor oversight where `fs_watcher.stop` was not type checked

# 1.0.0
- Initial release of the module