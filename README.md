# fs-watcher
This module is a utility to allow you to easily monitor any given directory for changes such as file creation, file modification, file deletion and allow you to run code when any of those events happen.

# Installation
Get this module from [lit](https://luvit.io/lit.html) with the following install command
```
lit install TohruMKDM/fs-watcher
```

# Usage
Using this module is extremely easy, below is a detailed example of use.
```lua
-- First we require the module
local fs_watcher = require('fs-watcher')

-- Create a new watcher for the current directory
fs_watcher.watch(
    './', -- Current directory
    false, -- Do not recursively monitor directories
    function(event, filepath, newpath) -- Assign callback function
        if event == 'update' then
            print(filepath..' was updated')
        elseif event == 'create' then
            print(filepath..' was created')
        elseif event == 'delete' then
            print(filepath..' was deleted')
        elseif event == 'rename' then
            print(filepath..' was renamed to '..newpath)
        end
        if event == 'error' then
            -- An error occured, 
            -- should be rare but just to be safe 
            -- it's probably best to stop monitoring past this point
            print('An error occured! '..filepath)
            fs_watcher.stop('./')
        end
    end
)
```

# Functions
A detailed explanation on what each function this module provides does.
## fs_watcher.watch(directory, recursive, callback)
| Parameter |   Type   | Optional |
| --------- | -------- |:--------:|
| directory | string   |          |
| recursive | boolean  |     ✔    |
| callback  | function |          |

Creates a new watcher to monitor the given directory for changes</br>
The callback's parameters are defined below</br></br>
**Returns:** [uv_fs_event_t](https://github.com/luvit/luv/blob/master/docs.md#uv_fs_event_t--fs-event-handle)

### callback(event, filepath, newpath)
| Parameter |   Type    |
| --------- | --------  |
|   event   |  string   |   
|  filepath |  string   |
|  newpath  |  string?  |

`filepath` will be the filepath of the relevant file **relative** to the directory the watcher is monitoring</br>
`newpath` will the new filepath in the event of a `rename` and `filepath` would be the old name</br>
If the callback returns a truthy value then it will automatically cancel the watcher for the directory the callback is assigned to.</br>
List of all possible events are defined below

### create
Fired when a file is created

### update
Fired when a file is modified

### delete
Fired when a file is deleted

### rename
Fired when a file is renamed

### error
Fired when an error occurs

## fs_watcher.stop(directory)
| Parameter |   Type   |
| --------- | -------- |
| directory |  string  |

Stops monitoring the given directory</br></br>

**Returns:** boolean, string?

## fs_watcher.stopAll()

Stops all active watchers</br></br>

**Returns:** boolean, string?

# Note
Every active watcher is a handle that will keep your event loop alive and as such your program will not exit until all of them are stopped or closed.
Make sure you call `fs_watcher.stop` on all directories a watcher is monitoring after you're done with them.