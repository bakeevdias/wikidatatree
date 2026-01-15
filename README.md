# Wikidata Hierarchical Tree

This visualization tool uses the main hierarchical relation types from Wikidata (subclass of, part of, instance of) to represent entities in a simple, hierarchical tree that is easy to traverse.



## Examples

- National cuisines with dishes: https://wikidatatree.xyz/?id=Q1968435
- Minerals: https://wikidatatree.xyz/?id=Q7946
- Swords: https://wikidatatree.xyz/?id=Q12791
- Cell components: https://wikidatatree.xyz/?id=Q5058355
- Computer science topics: https://wikidatatree.xyz/?id=Q21198
- Mountains: https://wikidatatree.xyz/?id=Q8502
- Tolkien races: https://wikidatatree.xyz/?id=Q989255
- Top entity: https://wikidatatree.xyz/?id=Q35120


## Usage

1. **Search**
   - Search for an entity in the search bar.
   - When an entity is selected, it appears as the top item in the list.
   - Using Wikidata’s own search often yields more relevant results:  
     https://www.wikidata.org/wiki/Wikidata:Main_Page

2. **Entity structure**

   Each entity contains the following parts:

   - **Toggle symbols**
     - `+` — entity has children and can be expanded
     - `.` — no children
     - `...` — loading data
     - `!` — error while fetching data

   - **(QID)**  
     Clicking the QID opens the corresponding Wikidata page with more information, including linked Wikipedia articles.

   - **↑**  
     Moves the entity to the top of the list and shows its parents.  
     The URL updates to include the entity’s QID.

   - **Description**  
     Shown on hover.

3. **Expanding entities**
   - Clicking an entity with `+` shows its children.
   - Child prefixes:
     - no prefix — subclasses of the parent (`subclass of`)
     - `part` — parts of the parent (`part of`)
     - `eg` — examples of the parent (`instance of`)
     

4. **Deep search**
   - Checkbox **Deep search** sets the child limit to **50,000** (default: 500).
   - Warning: may be slow for large hierarchies.


## Processing

Last fetched data on **2025-12-24 (y-m-d)** from:  
https://dumps.wikimedia.org/wikidatawiki/entities/20251222/wikidata-20251222-all.json.bz2

### Extracted fields from export
- `id`
- `said_to_be_the_same_as`
- `subclass_of`
- `instance_of`
- `part_of`
- `label`
- `description`
- `aliases`

For `label`, `description`, and `aliases`, a cascading language fallback is used: en > en-gb > en-ca > simple > mul > nl > ru > any other

### Additional processing
- Added entity **“ungrouped”** with QID `Q7`, and gave ungrouped items this entity, allowing them to be accessed in the tree.

## API Fields

- `label`  
  `label / alias1 / alias2 / ...`
- `children`  
  `subclass_of (P279)` + `part_of (P361)` + `instance_of (P31)` entities
- `parents`  
  Parent entities using the same relation types as `children`
- `has_child`  
  Indicates whether the entity has children
- `relation_type`  
  `subclass_of`, `part_of`, or `instance_of`

## SPARQL Version

The same tree is available using Wikidata SPARQL queries.  
It is slower and has some query limitations, but I assume it's always up to date.

https://wikidatatree.xyz/wikidata_sparql.html


