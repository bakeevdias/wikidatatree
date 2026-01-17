# Wikidata hierarchical tree

This visualization tool shows Wikidata items in a simple, hierarchical tree that is easily traversible. It answers the question of what the parents (hypernyms), children (hyponyms) or siblings (cohyponyms) are of an item in Wikidata. Relation types `subclass of`, `part of`, and `instance of` are used for this. 

## Examples
- national cuisines with dishes: https://wikidatatree.xyz/?id=Q1968435
- minerals: https://wikidatatree.xyz/?id=Q7946
- swords: https://wikidatatree.xyz/?id=Q12791
- cell components: https://wikidatatree.xyz/?id=Q5058355
- Pokémon species: https://wikidatatree.xyz/?id=Q3966183
- Tolkien races: https://wikidatatree.xyz/?id=Q989255
- entity is the top item: https://wikidatatree.xyz/?id=Q35120

## How to use

### Search bar

**Search for an item by typing in the search bar.** Max 100 items are fetched (TODO: apply infinite scroll). Results are shown in column `description` and `label`, with a sort on description. **Select an item and it appears as the top item in the tree.**

If the desired item isn't found, using [Wikidata’s own search](https://www.wikidata.org/wiki/Wikidata:Main_Page) can also help. The search there contains more relevant results. The unique ID (QID) can then be used in the url to access the item, like in the examples above.

### Parent items section

This section contains the parent links of the current item (TODO: sort in hierarchical order). Parent items have prefixes `subclass_of`, `part_of` and `instance_of` with `label/alias1/alias2...`. **Clicking on a parent means going upwards in the tree.**

### Hierarchical tree with items

Each item has the following structure:
   - Toggle symbols
     - `+`: item has child item(s) and can be expanded. **Clicking the + symbol fetches the child items**. The default is a maximum of 500 for speed, but the limit can be increased to 50k using checkbox `deep search`. 
     - `.`: item contains no further children
     - `...`: loading data.
     - `!`: error while fetching data
  - prefix: Child items can have certain prefixes:
     - `none`: subclass of the parent item (`subclass of`)
     - `part`: part of the parent item (`part of`)
     - `eg`: example of the parent item (`instance of`)
  - label/alias1/alias2/... The main label and all the aliases of the item.
   - (QID): Contains a link to the Wikidata page of the item with more information, including linked Wikipedia articles.
   - (↑): **Clicking this moves the item to the top of the tree.** This actually means going deeper into the tree. The URL updates to include the item's QID. The parents section will contain the previous parent, but also different ones, because an item can appear in multiple places in the tree.
   - description: **Hovering over an item shows its description if one is available.** If the item has expanded children the description is shown underneath its last child.



## Front end
A standalone [html page](public/index.html) is used to consume the API and render the tree.

[Another version](public/index_sparql.html) of this html page is available that uses Wikidata SPARQL queries. These are slower and have some limitations, but return data that is up to date. It actually doesn't need the sqlite database, except for the search bar. (TODO: use Wikidata search API so it fully works by itself) 


## Back end
[R code](scripts/process_wikidata.R) is used to process a Wikidata dump into a sqlite database. The dump is downloaded, unzipped, imported and processed in MongoDB, and then the sqlite database is generated as `/data/wikidata.db`.
This sqlite database is then queried by the [PHP API](public/api.php). It is quite performant for a single user, but is untested for concurrent users.

Last fetched data on 2025-12-24 (y-m-d) from: https://dumps.wikimedia.org/wikidatawiki/entities/20251222/wikidata-20251222-all.json.bz2

Extracted fields from export:
- `id`: QID
- `subclass_of`, `instance_of`, `part_of`: These relation types are used for both children and parents of items.
- `label`, `description`, `aliases`: For these a cascading language fallback is used: en > en-gb > en-ca > simple > mul > nl > ru > any other

To allow items without any parent to be accessed in the tree, all such items have been given a placeholder parent `ungrouped` (Q7), which in turn has `entity` (Q35120) as parent.








