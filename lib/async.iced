#!/usr/bin/env iced
# Copyright (c) 2013 r. brian harrison
# see LICENSE

once = (fn) ->
    (args...) ->
        f = fn
        fn = undefined
        f? args...

once_strict = (fn) ->
    (args...) ->
        throw new Error "Callback was already called." unless fn
        f = fn
        fn = undefined
        f args...

setImmediate = process?.nextTick

eachLate = (arr, iterator, autocb) ->
    # cb(err) after all iterators complete
    errors = {}
    await
        for item, i in arr
            iterator item, defer errors[i]
    for err in errors
        return err if err
    return null

each = forEach = (arr, iterator, cb) ->
    # UNDOCUMENTED cb is optional
    # cb(err) immediately upon first iterator error
    cb = once cb
    await
        for item in arr
            do (item, autocb=defer()) ->
                await iterator item, once_strict defer err
                return cb err if err
    cb null

# UNDOCUMENTED forEachSeries
eachSeries = forEachSeries = (arr, iterator, cb) ->
    # UNDOCUMENTED cb is optional
    for item in arr
        await iterator item, defer err
        return cb? err if err
    cb? null

# UNDOCUMENTED forEachLimit
eachLimit = forEachLimit = (arr, limit, iterator, cb) ->
    # UNDOCUMENTED cb is optional
    # UNDOCUMENTED non-positive limit returns empty list results
    return cb null, [] if limit < 1
    cb = once cb
    i = 0
    await
        for thread in [1..limit]
            do (autocb=defer()) ->
                while i < arr.length
                    await iterator arr[i++], defer err
                    return cb err if err
    cb null

map = (arr, iterator, cb) ->
    # UNDOCUMENTED cb is optional
    # UNDOCUMENTED obj mode was just a feature of parallel()
    cb = once cb
    if Array.isArray arr
        results = []
        await
            for item, i in arr
                do (item, i, autocb=defer()) ->
                    await iterator item, defer err, results[i]
                    return cb err if err
        cb null, results
    else
        results = {}
        await
            for attr, item of arr
                do (attr, item, autocb=defer()) ->
                    await iterator item, defer err, results[attr]
                    return cb err if err
        cb null, results

mapSeries = (arr, iterator, cb) ->
    # UNDOCUMENTED cb is optional
    if Array.isArray arr
        results = []
        for item, i in arr
            await iterator item, defer err, results[i]
            return cb err if err
        cb? null, results
    else
        results = {}
        for attr, item of arr
            await iterator item, defer err, results[attr]
            return cb err if err
        cb? null, results

mapLimit = (arr, limit, iterator, cb) ->
    # UNDOCUMENTED cb is optional
    # UNDOCUMENTED was just a feature of parallelLimit()
    # UNDOCUMENTED non-positive limit returns empty list results
    return cb null, [] if limit < 1
    cb = once cb
    if Array.isArray arr
        results = []
        i = 0
        await
            for thread in [1..limit]
                do (autocb=defer()) ->
                    while i < arr.length
                        await
                            iterator arr[i], defer err, results[i]
                            i++
                        return cb err if err
        cb null, results
    else
        results = {}
        mapLimit (k for k of arr), limit, (k, cb) ->
            await iterator arr[k], defer err, results[k]
            return cb err
        , (err) ->
            return cb err, results

filter = select = (arr, iterator, autocb) ->
    keep = []
    await
        for item, i in arr
            do (item, i, autocb=defer()) ->
                await iterator item, defer keep[i]
    kept = (item for item, i in arr when keep[i])
    return kept

filterSeries = selectSeries = (arr, iterator, autocb) ->
    results = []
    for item in arr
        await iterator item, defer result
        results.push item if result
    return results

reject = (arr, iterator, autocb) ->
    discard = []
    await
        for item, i in arr
            do (item, i, autocb=defer()) ->
                await iterator item, defer discard[i]
    kept = (item for item, i in arr when not discard[i])
    return kept

rejectSeries = (arr, iterator, autocb) ->
    results = []
    for item, i in arr
        await iterator item, defer result
        results.push item unless result
    return results

reduce = inject = foldl = (arr, memo, iterator, cb) ->
    for item in arr
        await iterator memo, item, defer err, memo
        return cb err if err
    cb null, memo

reduceRight = foldr = (arr, memo, iterator, cb) ->
    arr = arr.slice 0
    arr.reverse()
    reduce arr, memo, iterator, cb

detect = (arr, iterator, cb) ->
    # UNDOCUMENTED cb is optional
    cb = once cb
    await
        for item in arr
            do (item, autocb=defer()) ->
                await iterator item, defer satisfied
                cb item if satisfied
    cb null

detectSeries = (arr, iterator, autocb) ->
    for item in arr
        await iterator item, defer satisfied
        return item if satisfied
    return null

sortBy = (arr, iterator, cb) ->
    await map arr, iterator, defer err, results
    return cb err if err
    sort_arr = (criteria:results[i], value:arr[i] for _, i in arr)
    sort_arr.sort (a, b) ->
        a = a.criteria
        b = b.criteria
        if a > b then 1 else if a < b then -1 else 0
    cb null, (item.value for item in sort_arr)

some = any = (arr, iterator, cb) ->
    # UNDOCUMENTED cb is optional
    await detect arr, iterator, defer item
    cb not not item

every = all = (arr, iterator, cb) ->
    # UNDOCUMENTED cb is optional
    cb = once cb
    await
        for item in arr
            do (item, autocb=defer()) ->
                await iterator item, defer satisfied
                cb false unless satisfied
    cb true

concat = (arr, iterator, cb) ->
    cb = once cb
    results = []
    await
        for item, i in arr
            do (item, i, autocb=defer()) ->
                await iterator item, defer err, result
                return cb err if err
                results = results.concat result
    cb null, results

concatSeries = (arr, iterator, cb) ->
    cb = once cb
    results = []
    for item, i in arr
        await iterator item, defer err, result
        return cb err if err
        results = results.concat result
    cb null, results

dotask = (task, cb) ->
    task (err, args...) ->
        if args.length > 1
            return cb err, args
        else
            return cb err, args[0]

series = (tasks, cb) ->
    mapSeries tasks, dotask, cb

parallel = (tasks, cb) ->
    map tasks, dotask, cb

parallelLimit = (tasks, limit, cb) ->
    mapLimit tasks, limit, dotask, cb

whilst = (test, fn, autocb) ->
    while test()
        await fn defer err
        return err if err
    return null

doWhilst = (fn, test, autocb) ->
    loop
        await fn defer err
        return err if err
        return null unless test()

until_ = (test, fn, autocb) ->
    until test()
        await fn defer err
        return err if err
    return null

doUntil = (fn, test, autocb) ->
    loop
        await fn defer err
        return err if err
        return null if test()

forever = (fn, autocb) ->
    loop
        await fn defer err
        return err if err

waterfall = (tasks, cb) ->
    # UNDOCUMENTED cb is optional
    unless Array.isArray tasks
        return cb new Error 'First argument to waterfall must be an array of functions'
    cb = once cb
    args = []
    for task in tasks
        await task.call @, args..., defer err, args...
        return cb err if err
    cb null, args...

compose = (functions...) ->
    functions.reverse()
    (args..., cb) ->
        for fn in functions
            await fn.apply @, [args..., defer err, args...]
            return cb.call @, err if err
        cb.apply @, [null, args...]

applyEach = (functions, args..., cb) ->
    partial = (args..., cb) ->
        await
            for fn in functions
                do (fn, autocb=defer()) ->
                    await fn args..., defer err
                    return cb err if err
        cb null
    return partial unless cb
    partial args..., once cb

applyEachSeries = (functions, args..., autocb) ->
    for fn in functions
        await fn args..., defer err
        return err if err
    return null

queue = (worker, concurrency) ->
    throw 'nyi'

cargo = (worker, payload) ->
    throw 'nyi'

auto = (tasks, cb) ->
    # UNDOCUMENTED error provides results, i.e., cb(err, results)
    cb = once cb
    errored = false
    results = {}
    dependencies = {}
    for task_name of tasks
        dependencies[task_name] = []
    await
        for task_name, task of tasks
            do (task_name, task, autocb=defer()) ->
                return if errored
                if Array.isArray task
                    [task_deps..., task] = task
                    await
                        for dependency in task_deps
                            unless results.hasOwnProperty dependency
                                # XXX push would be faster, but fails unit tests
                                dependencies[dependency].unshift defer()
                await
                    task defer(err, result...), results
                switch result.length
                    when 0
                        result = undefined
                    when 1
                        result = result[0]
                results[task_name] = result
                errored or= err
                return cb err, results if err
                for task_cb in dependencies[task_name]
                    task_cb()
    cb null, results

iterator = (tasks) ->
    # UNDOCUMENTED iterators take args
    iteration = (i) ->
        fn = (args...) ->
            tasks[i]? args...
            fn.next()
        fn.next = ->
            if tasks[i + 1]
                iteration i + 1
        fn
    iteration 0

apply = (fn, args...) ->
    (more_args...) =>
        fn.apply @, [args..., more_args...]

nextTick = process?.nextTick

times = (n, iterator, cb) ->
    # UNDOCUMENTED iterator argument
    cb = once cb
    results = []
    await
        while n-- > 0
            do (n, autocb=defer()) ->
                iterator n, defer err, results[n]
                return cb err if err
    cb null, results

timesSeries = (n, iterator, cb) ->
    # UNDOCUMENTED iterator argument
    cb = once cb
    results = []
    i = 0
    while i < n
        await iterator i, defer err, results[i]
        return cb err if err
        i++
    cb null, results

memoize = (fn, hasher) ->

unmemoize = (fn) ->

log = (fn, args...) ->
    await fn args..., defer err, messages...
    return console.error err if err
    for message in messages
        console.log message

dir = (fn, args...) ->
    await fn args..., defer err, messages...
    return console.error err if err
    for message in messages
        console.dir message

previous_async = @async
noConflict = =>
    @async = previous_async
    async

async = {
    setImmediate
    once
    each
    forEach
    eachSeries
    forEachSeries
    eachLimit
    forEachLimit
    map
    mapSeries
    mapLimit
    filter
    select
    selectSeries
    filterSeries
    reject
    rejectSeries
    reduce
    inject
    foldl
    reduceRight
    foldr
    detect
    detectSeries
    sortBy
    some
    any
    every
    all
    concat
    concatSeries
    series
    parallel
    parallelLimit
    whilst
    doWhilst
    doUntil
    forever
    waterfall
    compose
    applyEach
    applyEachSeries
    queue
    cargo
    auto
    iterator
    apply
    nextTick
    times
    timesSeries
    memoize
    unmemoize
    log
    dir
    noConflict
}
async.until = until_
module?.exports = async
@async = async
