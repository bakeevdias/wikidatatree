###import data: 
#extract needed fields from wikidata dump under memory constrictions
#run mongoimport and if entities collection size above limit, pause cmd, run query to filter into another collection entities_slim, then delete entities and resume cmd

#improvements
#TODO: 25M records without label ?
#TODO: also_known_as simplification


wait_for_all_index_builds <- function(mongo_url = "") {
  mh=mongolite::mongo(db = "admin", url = mongo_url)
  repeat{
    op=mh$run(command = '{"currentOp":1}')$inprog$msg %>%  
      na.omit() %>% 
      as.character()
    
    if (length(op)==0) print("done")
    else print(op)
    
    if (!any(grepl("Index", op))) break
    Sys.sleep(10*60)
  }
}

try_again <- function(attempts=1, pause=0, expr={stop("no")}) {
  if (attempts < 1) return()
  
  expr=substitute(expr) #avoid warning: restarting interrupted promise evaluation
  for (att in 1:attempts) {
    res=tryCatch({
      eval(
        expr=expr, #prone to fail expression
        envir = parent.frame()) #try_again has to find vars if used inside a function
    },
    error = function(e) { 
      if (att != attempts) {
        print(paste0("error: ",e$message," (attempt ",att, ", sleep ",pause,"sec)"))
        Sys.sleep(pause)
      } else {
        print(paste0("error: ",e$message," (attempt ",att, ")")) #after last attempt don't wait
      }
      return(e)
    })
    
    #sometimes error, yet output is NULL and doesn't pass through error clause
    if (inherits(res, "NULL")) {
      if (att != attempts) Sys.sleep(pause)
      next()
    }
    
    if (!inherits(res, "error")) return(res)
  }
}

get_pid <- function() {
  
  try({ 
    pid = shell('tasklist /FI "IMAGENAME eq pbzip2.exe" /FO CSV', intern = T) |>
      paste0(collapse="\n") |>
      data.table::fread()
  })
  
  if (!exists("pid")) pid = integer(0)
  
  if (length(pid) != 0) {
    pid = dplyr::pull(pid, PID)
  }
  
  return(pid)
}

import_wikidata <- function(wikidata_dump_url) {

  shell(sprintf('wget -c -t 5 --wait=10 "%s" -O "latest-all.json.bz2"', wikidata_dump_url)) |> print()
  shell("pbzip2 -dc latest-all.json.bz2 | mongoimport --db wikidata --collection entities --jsonArray --numInsertionWorkers 4 --bypassDocumentValidation", wait = F, intern = T) |> print()
  
  repeat({
    Sys.sleep(60*2)
    
    #in case processes is done and gone
    pid = get_pid()
    
    try_again(4, 1, {x = me$info()$stats})
    s = utils:::format.object_size(x$storageSize, "auto")
    s = gsub("Gb","", s)
    s = stringr::str_trim(s)
    s = as.numeric(s)
    
    #pid is gone when process done
    #s is NA if below Gb
    if (length(pid)== 0 || (!is.na(s) && s > 20)) {
      sapply(sprintf("pssuspend %s", pid), shell)
      
      Sys.sleep(30) #wait for mongoimport to finish after suspending
      try_again(4, 1, {n_me = me$info()$stats$count})
      try_again(4, 1, {n_mes = mess$info()$stats$count})
      expected_mes_count = n_mes + n_me
      
      # Error: [Failed to write rpc bytes. calling hello on 'localhost:27017']
      try(create_entities_slim())
      
      repeat({
        try_again(4, 1, {n_mes = mess$info()$stats$count})
        if (n_mes == expected_mes_count) break
        Sys.sleep(60*2)
      })
      
      me$drop()
      
      Sys.sleep(60*2) #cool off
      
      sapply(sprintf("pssuspend -r %s", pid), shell)
      if (length(pid) == 0) break
    }
  })
  
  try(mess$index('{"id":1}'))
  try(mess$index('{"instance_of":1}'))
  try(mess$index('{"subclass_of":1}'))
  try(mess$index('{"part_of":1}'))
  try(mess$index('{"child_of":1}'))
  try(mess$index('{"label":1}'))
  try(mess$index('{"description":1}'))
  try(mess$index('{"label": "text","description": "text"}'))
}

create_entities_slim <- function() {
  
  id = mess$aggregate('[
    {"$sort":{"_id":-1}},
    {"$limit":1}
  ]')$`_id`
  
  match = ifelse(is.null(id), "", sprintf('{"$match":{"_id": {"$gt": {"$oid": "%s"}}}},', id))
  q = sprintf('[
  %s
  {"$project":{
      "_id":1,
      "id": 1,
      "label": { "$switch": {
          "branches": [
            {"case":{"$ne":[{"$type":"$labels.en.value"},"missing"]},"then":["$labels.en.value"]},
            {"case":{"$ne":[{"$type":"$labels.en-gb.value"},"missing"]},"then":["$labels.en-gb.value"]},
            {"case":{"$ne":[{"$type":"$labels.en-ca.value"},"missing"]},"then":["$labels.en-ca.value"]},
            {"case":{"$ne":[{"$type":"$labels.simple.value"},"missing"]},"then":["$labels.simple.value"]},
            {"case":{"$ne":[{"$type":"$labels.mul.value"},"missing"]},"then":["$labels.mul.value"]},
            {"case":{"$ne":[{"$type":"$labels.nl.value"},"missing"]},"then":["$labels.nl.value"]},
            {"case":{"$ne":[{"$type":"$labels.ru.value"},"missing"]},"then":["$labels.ru.value"]}
          ],
          "default": {"$let":{
            "vars":{"first_label":{"$arrayElemAt": [{"$objectToArray": "$labels" }, 0]}},
            "in": ["$$first_label.v.value"]}}}},
      "description": { "$switch": {
          "branches": [
            {"case":{"$ne":[{"$type":"$descriptions.en.value"},"missing"]},"then":"$descriptions.en.value"},
            {"case":{"$ne":[{"$type":"$descriptions.en-gb.value"},"missing"]},"then":"$descriptions.en-gb.value"},
            {"case":{"$ne":[{"$type":"$descriptions.en-ca.value"},"missing"]},"then":"$descriptions.en-ca.value"},
            {"case":{"$ne":[{"$type":"$descriptions.simple.value"},"missing"]},"then":"$descriptions.simple.value"},
            {"case":{"$ne":[{"$type":"$descriptions.mul.value"},"missing"]},"then":"$descriptions.mul.value"},
            {"case":{"$ne":[{"$type":"$descriptions.nl.value"},"missing"]},"then":"$descriptions.nl.value"},
            {"case":{"$ne":[{"$type":"$descriptions.ru.value"},"missing"]},"then":"$descriptions.ru.value"}
          ],
          "default": {"$let":{
            "vars":{"first_label":{"$arrayElemAt": [{"$objectToArray": "$descriptions" }, 0]}},
            "in": "$$first_label.v.value"}}}},
      "aliases": { "$switch": {
          "branches": [
            {"case":{"$ne":[{"$type":"$aliases.en.value"},"missing"]},"then":["$aliases.en.value"]},
            {"case":{"$ne":[{"$type":"$aliases.en-gb.value"},"missing"]},"then":["$aliases.en-gb.value"]},
            {"case":{"$ne":[{"$type":"$aliases.en-ca.value"},"missing"]},"then":["$aliases.en-ca.value"]},
            {"case":{"$ne":[{"$type":"$aliases.simple.value"},"missing"]},"then":["$aliases.simple.value"]},
            {"case":{"$ne":[{"$type":"$aliases.mul.value"},"missing"]},"then":["$aliases.mul.value"]},
            {"case":{"$ne":[{"$type":"$aliases.nl.value"},"missing"]},"then":["$aliases.nl.value"]},
            {"case":{"$ne":[{"$type":"$aliases.ru.value"},"missing"]},"then":["$aliases.ru.value"]}
           ],
          "default": []}},   
      "said_to_be_the_same_as":"$claims.P460.mainsnak.datavalue.value.id",
      "subclass_of": "$claims.P279.mainsnak.datavalue.value.id",
      "instance_of": "$claims.P31.mainsnak.datavalue.value.id",
      "part_of": "$claims.P361.mainsnak.datavalue.value.id",
      "facet_of":"$claims.P1269.mainsnak.datavalue.value.id"}},
  {"$addFields": {
      "label": {"$reduce": {
        "input": {"$concatArrays":[["$label"], {"$filter": {
        	"input": "$aliases",
            "as": "item",
            "cond": { "$ne": ["$$item", null] }}}]},
        "initialValue": [],
        "in": { "$concatArrays": [
              "$$value",
              "$$this"]}}},
      "child_of": {"$concatArrays":[
        {"$ifNull": ["$subclass_of", []]},
        {"$ifNull": ["$part_of", []]},
        {"$ifNull": ["$instance_of", []]}]},
      "aliases": "$$REMOVE" }},
  {"$addFields": {
      "label": {"$reduce": {
        "input": "$label",
        "initialValue": "",
        "in": {"$concat": [
          "$$value",
          {"$cond": {
            "if": {"$eq": [
              "$$value",
              ""]},
            "then": "",
            "else": "/"}},
          "$$this"]}}}}},
  {"$merge": "entities_slim_staging"}]', match)
  me$aggregate(q)
  
}

add_has_child <- function() {
  
  mess2$aggregate('[
    {"$unwind":{"path":"$child_of","preserveNullAndEmptyArrays":false}},
    {"$group":{"_id":"$child_of"}},
    {"$project":{"_id":1,"is_parent":true}},
    {"$out":"has_child"}
  ]');
  
  #wait until has_child collection is done
  repeat({
    x = ma$run(command = '{"currentOp":1}')$inprog$command
    if (all(sapply(x$pipeline, length)== 0)) break
    Sys.sleep(60)
  })
  
  
  mhs=mongolite::mongo(url = "mongodb://localhost:27017/", db="wikidata", collection = "has_child")
  ids = mhs$find(fields = '{"_id":1}')
  
  mess2$update(
    query='{}',
    update='{"$set":{"has_child": false}}',
    multiple=T)
  
  mess2$update(
    query=jsonlite::toJSON(list("id" = list("$in" = ids[1:400000,]))),
    update='{"$set":{"has_child": true}}',
    multiple=T)
  
  mess2$update(
    query=jsonlite::toJSON(list("id" = list("$in" = ids[400001:nrow(ids),]))),
    update='{"$set":{"has_child": true}}',
    multiple=T)
  
  mhs$drop()
  
  return("done")
}

unisolate_items <- function() {
  mess2$insert('{
    "_id":"68336efef61a7b6ee0038875",
    "description" : "unofficial placeholder for ungrouped items",
    "id" : "Q7",
    "label" : "ungrouped",
    "child_of" : ["Q35120"],
    "subclass_of" : ["Q35120"], 
    "has_child":true
  }')
  
  mess2$update(
    query='{"child_of":[]}',
    update='{"$set":{
      "child_of":["Q7"], 
      "subclass_of":["Q7"]}}',
    multiple=T)
  
  return("done")
}

create_wikidata_sqlite_db <- function() {
  
  link_fields = c("instance_of", "subclass_of", "part_of", "said_to_be_the_same_as")
  for (field in link_fields) {
    print(field)
    mes2$aggregate(sprintf('[
      {"$unwind":"$%s"},
      {"$project":{"_id":0, "id":1, "%s":1}},
      {"$out":"entities_slim_%s"}
    ]', field, field, field))

    shell(sprintf("mongoexport --db wikidata --collection entities_slim_%s --type=csv  --out=entity_slim_%s.csv --fields=id,%s", field, field, field), wait = F)
  }
  
  #has to pass through jq csv, because of quote handling -> entity_slim_scalar.csv:46259: unterminated "-quoted field
  writeLines("id,label,description,has_child,latitude,longitude", "entity_slim_scalar.csv")
  shell("mongoexport --db wikidata --collection entities_slim --type=json --fields=id,label,description,has_child,latitude,longitude | jq -r \"[.id, .label, .description, .has_child, .latitude, .longitude] | @csv\" >> entity_slim_scalar.csv", wait = T)
  
  shell("sqlite3 wikidata.db < ../db/schema.sql")
  shell("sqlite3 wikidata.db <../db/import.sql")
  
  return("done")
}

send_db_via_ftp <- function() {
  shell("zip wikidata.db.zip wikidata.db")
  shell("wsl -e split -b 6G wikidata.db.zip wikidata.db.zip.part_")
  parts <- list.files(
    pattern = "^wikidata\\.db\\.zip\\.part_",
    full.names = TRUE)
  for (p in parts) {
    curl::curl_upload(
      file = p,
      url = paste0(Sys.getenv("ftp_url"), basename(p)), 
      userpwd = sprintf("%s:%s", Sys.getenv("ftp_user"), Sys.getenv("ftp_pass"))
    )
  }
  
  return("done")
}

clear_state <- function() {
  if (readline("clear state [y/n]? ") != "y") return()
  if (grepl("/data$", getwd())) dir() |> file.remove()
  pid = get_pid()
  sapply(sprintf("pskill %s", pid), shell)
  me$run(command = '{"dropDatabase": 1}')
}

#setup:
#windows: choco install sqlite mongodb pbzip2 procexp pstools
#set laptop to high performance!!!
  #set windows power plan turbo, turn off display never, otherwise it goes back to balanced if screen turns off
  #minimal screen usage: brightness lowest, careueyes 0%, make desktop clean black
  #if power unplugged and plugged, it also goes back to balanced
  #set ghelper
    #mode turbo, gpu mode ultimate (gpu not used?)
    #fans+power
      #CPU > CPU boost aggressive at guaranteed, windows power mode best performance
      #advanced > calibrate and set CPU temp limit 95 degrees

setwd("../data")
readRenviron("../.Renviron")

wikidata_dump_url = "https://dumps.wikimedia.org/wikidatawiki/entities/20251222/wikidata-20251222-all.json.bz2"
# wikidata_dump_url = "https://dumps.wikimedia.org/wikidatawiki/entities/latest-all.json.bz2" #not available?

me=mongolite::mongo(url = "mongodb://localhost:27017/?sockettimeoutms=1000", db="wikidata", collection = "entities")
mes=mongolite::mongo(url = "mongodb://localhost:27017/?sockettimeoutms=1000", db="wikidata", collection = "entities_slim")
mes2=mongolite::mongo(url = "mongodb://localhost:27017/?sockettimeoutms=72000000", db="wikidata", collection = "entities_slim")
mess=mongolite::mongo(url = "mongodb://localhost:27017/", db="wikidata", collection = "entities_slim_staging")
mess2=mongolite::mongo(url = "mongodb://localhost:27017/?sockettimeoutms=72000000", db="wikidata", collection = "entities_slim_staging")
ma=mongolite::mongo(url = "mongodb://localhost:27017/", db="admin")


clear_state()
import_wikidata(wikidata_dump_url)
add_has_child()
unisolate_items()
wait_for_all_index_builds("mongodb://localhost:27017/?sockettimeoutms=72000000")
if (mess$info()$stats$count > 100000000) {
  #last count: 118530858
  mes$drop()
  mess$rename("entities_slim")
}
create_wikidata_sqlite_db()
send_db_via_ftp()
#shell("psshutdown -d -t 0")


#merge parts and unzip in server
#cat wikidata.db.zip.part_* >  wikidata.db.zip
#unzip wikidata.db.zip

