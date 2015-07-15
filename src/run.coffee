fs = require('fs')
documentDBUtils = require('documentdb-utils')
{OLAPCube} = require('lumenize')
DocumentClient = require("documentdb").DocumentClient

console.log(process.env.DOCUMENT_DB_URL, process.env.DOCUMENT_DB_KEY)

#filterQuery = 'SELECT * FROM Facts WHERE Facts.Priority = 1'
filterQuery = null

dimensions = [
  {field: "ProjectHierarchy", type: 'hierarchy'},
  {field: "Priority"}
]

metrics = [
  {field: "Points", f: "sum", as: "Scope"}
]

cubeConfig = {dimensions, metrics}
cubeConfig.keepTotals = true

cachedResultsFile = './cached-results.json'
results = {}

run = (req, res, next) ->

  usingStoredProcedure = () ->

    {cube} = require('documentdb-lumenize')

    config =
      databaseID: 'test-stored-procedure'
      collectionID: 'testing-s3'
      storedProcedureID: 'cube'
      storedProcedureJS: cube
      memo: {cubeConfig, filterQuery}
      debug: true

    processResponse = (err, response) ->
      console.log(response.stats)
      cube = OLAPCube.newFromSavedState(response.memo.savedCube)
      console.log(cube.toString(null, null, '_count'))
      if err?
        throw new Error(JSON.stringify(err))

      results.spTime = response.stats.executionTime
      results.spRUs = response.stats.totalRequestCharges

      readingDirectly(response.collectionLink)

    documentDBUtils(config, processResponse)

  runAfter = (delay, f) ->
    setTimeout(f, delay)

  readingDirectly = (collectionLink) ->
    console.time('readingDirectly')
    console.log(collectionLink)
    totalRequestCharges = 0
    startTime = new Date()
    client = new DocumentClient(process.env.DOCUMENT_DB_URL, {masterKey: process.env.DOCUMENT_DB_KEY})
    cube = new OLAPCube(cubeConfig)

    processNextPage = (err, resources, header) ->
      if err? and err.code is 429
        delay = Number(header['x-ms-retry-after-ms']) or 0
        runAfter(delay, () ->
          iterator.executeNext(processNextPage)
        )
      else if err?
        console.log(JSON.stringify(err))
      console.log(resources.length)
      totalRequestCharges += Number(header['x-ms-request-charge'])
      console.log(totalRequestCharges)
      cube.addFacts(resources)
      if iterator.hasMoreResults()
        iterator.executeNext(processNextPage)
      else
        console.log(cube.toString(null, null, '_count'))
        console.timeEnd('readingDirectly')
        console.log('Total RUs: ', totalRequestCharges)
        results.directTime = new Date() - startTime
        results.directRUs = totalRequestCharges
        console.log('\n')
        console.log(results)
        fs.writeFileSync(cachedResultsFile, JSON.stringify(results), 'utf8')
        res.send(200, results)
        next()


    if filterQuery?
      iterator = client.queryDocuments(collectionLink, filterQuery, {maxItemCount: 1000})
    else
      iterator = client.readDocuments(collectionLink, {maxItemCount: 1000})

    iterator.executeNext(processNextPage)

  if fs.existsSync(cachedResultsFile)
    fileContentsString = fs.readFileSync(cachedResultsFile, 'utf8')
    res.send(200, JSON.parse(fileContentsString))

  usingStoredProcedure()


exports.run = run