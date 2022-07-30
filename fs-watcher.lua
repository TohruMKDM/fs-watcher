--[[lit-meta
	name = 'TohruMKDM/fs-watcher'
	version = '1.0.1'
	homepage = 'https://github.com/TohruMKDM/fs-watcher'
	description = 'Utility to allow callbacks to be assigned to fs operations such file creation, deletion, and modification.'
	tags = {'utility', 'watcher', 'fs'}
	license = 'MIT'
	author = {name = 'Tohru~ (トール)', email = 'admin@ikaros.pw'}
]]

local uv = require('uv')
local fs = require('fs')
local path = require('pathjoin')

local fs_event, fs_stat = uv.new_fs_event, uv.fs_stat
local scandirSync = fs.scandirSync
local pathJoin = path.pathJoin

local error_format = 'bad argument #%d to %q (%s expected, got %s)'

--- Weak cache of all the currently active fs-watchers
--- @type table<string, uv_fs_event_t>
local watchers = setmetatable({}, {__mode = 'k'})

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
            output[entryPath] = {size = stat.size, mtime = stat.mtime}
        end
    end
    return output
end

--- @alias watcher_callback_events
--- Fired when a file is modified
---|'update'
--- Fired when a file is created
---|'create'
--- Fired when a file is deleted
---|'delete'
--- Fired when an error occurs
---|'error'

--- Creates a new watcher to monitor the given directory for changes
--- @param directory string The directory you want to monitor
--- @param recursive boolean Whether or not to monitor changes recursively
--- @param callback fun(event: watcher_callback_events, filepath: string)
--- @return uv_fs_event_t
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
    local oldWatcher = watchers[directory]
    if oldWatcher then
        oldWatcher:stop()
        watchers[directory] = nil
    end
    local info = getInfo(directory, recursive)
    local watcher = assert(fs_event())
    local success, err = watcher:start(directory, {recursive = recursive}, function(err, entry, event)
        if err then
            callback('error', err)
            return
        end
        local entryPath = pathJoin(directory, entry)
        if event.change then
            local stat = assert(fs_stat(entryPath))
            local size, mtime = stat.size, stat.mtime
            local old = info[entryPath]
            if size ~= 0 and (mtime.sec ~= old.mtime.sec or mtime.nsec ~= old.mtime.nsec) then
                info[entryPath] = {size = size, mtime = mtime}
                callback('update', entryPath)
            end
            return
        end
        local stat = fs_stat(entryPath)
        if stat then
            info[entryPath] = {size = stat.size, mtime = stat.mtime}
            callback('create', entryPath)
        else
            info[entryPath] = nil
            callback('delete', entryPath)
        end
    end)
    if not success then
        error(err, 2)
    end
    watchers[directory] = watcher
    return watcher
end

--- Stops monitoring the given directory
--- @param directory string The directory you want to stop monitoring
--- @return boolean success, string? err_msg
local function stop(directory)
    if type(directory) ~= 'string' then
        error(error_format:format(1, 'stop', 'string', type(directory)), 2)
    end
    local watcher = watchers[directory]
    if watcher then
        local success, err = watcher:stop()
        if not success then
            return false, err
        end
        watchers[directory] = nil
        return true
    end
    return  false
end

return {
    watch = watch,
    stop = stop
}