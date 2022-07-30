local watcher = require('./fs-watcher')
local fs = require('fs')
local timer = require('timer')

local createCalled = false
local updateCalled = false
local deleteCalled = false


fs.mkdirSync('testing')
timer.sleep(500)

watcher.watch('testing', false, function(name, file)
    if name == 'create' then
        assert(file == 'testing/file.lua', 'create event called with unexpected file')
        print('create event passed')
        createCalled = true
    end
    if name == 'update' then
        assert(file == 'testing/file.lua', 'update event called with unexpected file')
        print('update event passed')
        updateCalled = true
    end
    if name == 'delete' then
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

fs.rmdirSync('testing')
timer.sleep(500)

assert(createCalled, 'create event not called')
assert(updateCalled, 'update event not called')
assert(deleteCalled, 'delete event not called')

print('All tests passed!')