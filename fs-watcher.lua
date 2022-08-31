--[[lit-meta
	name = 'TohruMKDM/fs-watcher'
	version = '2.0.0'
	homepage = 'https://github.com/TohruMKDM/fs-watcher'
	description = 'Utility to allow callbacks to be assigned to fs operations such file creation, deletion, and modification.'
	tags = {'utility', 'watcher', 'fs'}
	license = 'MIT'
	author = {name = 'Tohru~ (トール)', email = 'admin@ikaros.pw'}
]]

local uv = require('uv')
local fs = require('fs')
local path = require('pathjoin')
local timer = require('timer')
local utils = require('utils')

local fs_event, fs_stat = uv.new_fs_event, uv.fs_stat
local scandirSync = fs.scandirSync
local pathJoin = path.pathJoin
local setImmediate, setTimeout, clearTimeout = timer.setImmediate, timer.setTimeout, timer.clearTimeout
local assertResume = utils.assertResume

local running, yield = coroutine.running, coroutine.yield

local error_format = 'bad argument #%d to %q (%s expected, got %s)'

--- Weak cache of all the currently active fs-watchers
--- @type table<function, uv_fs_event_t>
local watchers = setmetatable({}, {__mode = 'k'})
--- Weak cache of all the watchers assigned to a given directory
--- @type table<string, uv_fs_event_t[]>
local directories = setmetatable({}, {__mode = 'k'})

--- Gets the last modification time for every entry in a given directory
--- @param directory string The directory you want to get last modification time on
--- @param recursive? boolean If you want the search to be recursive or not
--- @param output? table The table you want to load information to
--- @return table<string, {size: integer, mtime: {nsec: integer, sec: integer}}>
local function getInfo(directory, recursive, output)
    output = output or {}
    for entry, entryType in scandirSync(directory) do
        local entryPath = pathJoin(directory, entry)
        if recursive and entryType == 'directory' then
            getInfo(entryPath, recursive, output)
        elseif entryType == 'file' then
            local stat = assert(fs_stat(entryPath))
            output[entryPath] = {size = stat.size, mtime = stat.mtime, birthtime = stat.birthtime, path = entryPath}
        end
    end
    return output
end

--- Stops triggering a callback
--- @param callback function The callback you want to stop triggering
--- @return boolean success, string? err_msg
local function stop(callback)
    if type(callback) ~= 'function' then
        error(error_format:format(1, 'stop', 'function', type(callback)), 2)
    end
    local watcher = watchers[callback]
    if watcher then
        local success, err = watcher:stop()
        if not success then
            return false, err
        end
        watcher:close()
        watchers[callback] = nil
        local list = directories[watcher:getpath()]
        if list then
            for i = 1, #list do
                if list[i] == watcher then
                    list[i] = nil
                end
            end
        end
        return true
    end
    return false, 'No active watcher for that callback'
end

--- Stops all active watchers for a given directory
--- @param directory? string The directory you want to stop watchers on
--- @return boolean success, string? err_msg
local function stopAll(directory)
    if type(directory) ~= 'string' and type(directory) ~= 'nil' then
        error(error_format:format(1, 'stopAll', 'string/nil', type(directory)), 2)
    end
    if directory then
        local list = directories[directory]
        if not list then
            return false, 'No active watchers for this directory'
        end
        for i = #list, 1, -1 do
            local success, err = list[i]:stop()
            if not success then
                return false, err
            end
            list[i]:close()
            list[i] = nil
        end
        return true
    end
    for callback, watcher in pairs(watchers) do
        local success, err = watcher:stop()
        if not success then
            return false, err
        end
        watchers[callback] = nil
    end
    return true
end

local function handleCallback(fn, ...)
    if fn(...) then
        stop(fn)
    end
end

--- @alias watcher_callback_events
--- Fired when a file is modified
---|'update'
--- Fired when a file is created
---|'create'
--- Fired when a file is deleted
---|'delete'
--- Fired when a file is renamed
---|'rename'
--- Fired when an error occurs
---|'error'

--- Creates a new watcher to monitor the given directory for changes
--- @param directory string The directory you want to monitor
--- @param recursive boolean Whether or not to monitor changes recursively
--- @param callback fun(event: watcher_callback_events, filepath: string, newpath?: string): boolean?
--- @return function, uv_fs_event_t
local function watch(directory, recursive, callback)
    if type(directory) ~= 'string' then
        error(error_format:format(1, 'watch', 'string', type(directory)), 2)
    end
    if type(recursive) ~= 'boolean' and type(recursive) ~= 'nil' then
        error(error_format:format(2, 'watch', 'boolean/nil', type(recursive)), 2)
    end
    if type(callback) ~= 'function' then
        error(error_format:format(3, 'watch', 'function', type(callback)), 2)
    end
    local info = getInfo(directory, recursive)
    local lastDeleted, createCalled
    local watcher = assert(fs_event())
    local success, err = watcher:start(directory, {recursive = recursive}, function(err, entry, event)
        if err then
            handleCallback(callback, 'error', err)
            return
        end
        local entryPath = pathJoin(directory, entry)
        if event.change then
            local stat = assert(fs_stat(entryPath))
            local size, mtime = stat.size, stat.mtime
            local old = info[entryPath]
            if size ~= 0 and (mtime.sec ~= old.mtime.sec or mtime.nsec ~= old.mtime.nsec) then
                info[entryPath] = {size = size, mtime = mtime, birthtime = stat.birthtime, path = entryPath}
                handleCallback(callback, 'update', entryPath)
            end
            return
        end
        local stat = fs_stat(entryPath)
        if stat then
            createCalled = true
            info[entryPath] = {size = stat.size, mtime = stat.mtime, birthtime = stat.birthtime, path = entryPath}
            if lastDeleted and lastDeleted.birthtime.nsec == stat.birthtime.nsec and lastDeleted.birthtime.sec == stat.birthtime.sec then
                handleCallback(callback, 'rename', lastDeleted.path, entryPath)
                lastDeleted = nil
                return
            end
            handleCallback(callback, 'create', entryPath)
        else
            lastDeleted = info[entryPath]
            info[entryPath] = nil
            setImmediate(function()
                if not createCalled then
                    handleCallback(callback, 'delete', entryPath)
                end
                createCalled = nil
            end)
        end
    end)
    if not success then
        error(err, 2)
    end
    if not directories[directory] then
        directories[directory] = {}
    end
    directories[directory][#directories[directory] + 1] = watcher
    watchers[callback] = watcher
    return callback, watcher
end

--- Waits for a singular change in a given directory with a optional timeout and predicate
--- @param directory string The directory you want to wait for
--- @param recursive boolean Whether or not to wait for a change recursively
--- @param timeout? integer Timeout duration (in milliseconds)
--- @param predicate? fun(event: watcher_callback_events, filepath: string, newpath?: string): boolean?
--- @return boolean success, watcher_callback_events? event, string? filepath, string? newpath
local function waitForChange(directory, recursive, timeout, predicate)
    if type(directory) ~= 'string' then
        error(error_format:format(1, 'waitForChange', 'string', type(directory)), 2)
    end
    if type(recursive) ~= 'boolean' then
        error(error_format:format(2, 'waitForChange', 'boolean', type(directory)), 2)
    end
    if type(timeout) ~= 'number' and type(timeout) ~= 'nil' then
        error(error_format:format(3, 'waitForChange', 'number/nil', type(timeout)), 2)
    end
    if type(predicate) ~= 'function' and type(predicate) ~= 'nil' then
        error(error_format:format(4, 'waitForChange', 'function/nil', type(directory)), 2)
    end
    local thread, main = running()
    if main then
        error('This method must be called inside of a coroutine.', 2)
    end
    local fn, tmout
    fn = watch(directory, recursive, function(...)
        if predicate and not predicate(...) then
            return
        end
        if tmout then
            clearTimeout(tmout)
        end
        stop(fn)
        assertResume(thread, true, ...)
    end)
    if timeout then
        tmout = setTimeout(timeout, function()
            stop(fn)
            assertResume(thread, false)
        end)
    end
    return yield()
end

return {
    watch = watch,
    stop = stop,
    stopAll = stopAll,
    waitForChange = waitForChange,
    watchers = watchers,
    directories = directories
}