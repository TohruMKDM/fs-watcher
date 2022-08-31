local watcher = require('./fs-watcher')
local fs = require('fs')
local timer = require('timer')

local createCalled = false
local updateCalled = false
local deleteCalled = false
local renameCalled = false
local waitFor

fs.mkdirSync('testing')
timer.sleep(500)

local fn = watcher.watch('testing', false, function(event, path, newpath)
    if event == 'create' then
        assert(path == 'testing/file.lua', 'create event called with unexpected path')
        print('create event passed')
        createCalled = true
    end
    if event == 'update' then
        assert(path == 'testing/file.lua', 'update event called with unexpected path')
        print('update event passed')
        updateCalled = true
    end
    if event == 'delete' then
        assert(path == 'testing/file.txt', 'delete event called with unexpected path')
        print('delete event passed')
        deleteCalled = true
    end
    if event == 'rename' then
        assert(path == 'testing/file.lua', 'rename event called with unexpected path')
        assert(newpath == 'testing/file.txt', 'rename event called with unexpected newpath')
        print('rename event passed')
        renameCalled = true
    end
end)

fs.writeFileSync('testing/file.lua', '...')
timer.sleep(500)

fs.writeFileSync('testing/file.lua', 'update')
timer.sleep(500)

fs.renameSync('testing/file.lua', 'testing/file.txt')
timer.sleep(500)

fs.unlinkSync('testing/file.txt')
timer.sleep(500)

watcher.stop(fn)
timer.sleep(500)

coroutine.wrap(function()
    local _, event, filepath = watcher.waitForChange('testing', false, nil, function(event, filepath)
        return event == 'create' and filepath == 'testing/file2.txt'
    end)
    if event =='create' then
        waitFor = filepath
        if filepath == 'testing/file2.txt' then
            print('waitFor test passed')
        end
    end
end)()

fs.writeFileSync('testing/file1.txt', '...')
timer.sleep(500)

fs.writeFileSync('testing/file2.txt', '...')
timer.sleep(500)

assert(createCalled, 'create event not called')
assert(updateCalled, 'update event not called')
assert(deleteCalled, 'delete event not called')
assert(renameCalled, 'rename event not called')
assert(waitFor == 'testing/file2.txt', 'waitFor did not return the correct file')
assert(next(watcher.watchers) == nil, 'watchers not stopped')

fs.unlinkSync('testing/file1.txt')
fs.unlinkSync('testing/file2.txt')
timer.sleep(500)

fs.rmdirSync('testing')
timer.sleep(500)

print('All tests passed!')