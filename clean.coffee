config = require("./configure")
db = require("./database")

db.Plunk.count({_id: $in: [

]}, (err) -> console.log "DONE", arguments...)