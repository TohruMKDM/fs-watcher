# 2.0.0
- Added new method `waitForChange` which allows you to wait for a single change on a given directory with an optional timeout and predicate
- `stopAll` now takes a `directory` argument to only stop watchers on a specific directory
- Changed how `stop` and `stopAll` works
- Exposed the weak cache of watchers

# 1.1.0
- Added a new `rename` event which fires when a file is renamed
- Added a new method `fs_watcher.stopAll` which stops all running watchers

# 1.0.2
- Made the callback automatically stop the watcher if a truthy value is returned

# 1.0.1
- Fix very minor oversight where `fs_watcher.stop` was not type checked

# 1.0.0
- Initial release of the module