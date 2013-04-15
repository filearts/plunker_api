_ = require("underscore")._
nconf = require("nconf")



apiErrors = require("../errors")
apiUrl = nconf.get('url:api')
database = require("../database")

{Plunk} = database


exports.list = (req, res, next) ->
  pipeline = []
  
  pipeline.push $unwind:
    "$tags"
  pipeline.push $group:
    _id: "$tags"
    count: $sum: 1
  if q = req.param("q") then pipeline.push $match:
    _id: $regex: "^#{q}", $options: "i"
  pipeline.push $sort:
    count: -1
  pipeline.push $limit:
    10
  
  Plunk.aggregate pipeline, (err, results) ->
    return next(err) if err
    
    res.json _.map results, (record) ->
      tag: record._id
      count: record.count