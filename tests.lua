local watcher = require('./fs-watcher')
local fs = require('fs')
local timer = require('timer')

local createCalled = false
local updateCalled = false
local deleteCalled = false

fs.mkdirSync('testing')
timer.sleep(500)

watcher.watch('testing', false, function(event, file)
    if event == 'create' then
        assert(file == 'testing/file.lua', 'create event called with unexpected file')
        print('create event passed')
        createCalled = true
    end
    if event == 'update' then
        assert(file == 'testing/file.lua', 'update event called with unexpected file')
        print('update event passed')
        updateCalled = true
    end
    if event == 'delete' then
        assert(file == 'testing/file.lua', 'delete event called with unexpected file')
        print('delete event passed')
        deleteCalled = true
    end
end)

fs.writeFileSync('testing/file.lua', '...')
timer.sleep(500)

fs.writeFileSync('testing/file.lua', 'update')
timer.sleep(500)

fs.unlinkSync('testing/file.lua')
timer.sleep(500)

watcher.stop('testing')
timer.sleep(500)

assert(createCalled, 'create event not called')
assert(updateCalled, 'update event not called')
assert(deleteCalled, 'delete event not called')

watcher.watch('testing', false, function()
    return true
end)

fs.writeFileSync('testing/x.txt', '...')
timer.sleep(500)

assert(not watcher.stop('testing'), 'fs_watcher auto cancellation not passed')
print('fs_watcher auto cancellation passed')

fs.unlinkSync('testing/x.txt')
timer.sleep(500)

fs.rmdirSync('testing')
timer.sleep(500)

print('All tests passed!')