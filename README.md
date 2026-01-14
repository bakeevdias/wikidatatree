#Wikidata hierarchical tree
This visualisation tool uses the main hierarchical relation types (subclass_of, part_of, instance_of) from Wikidata to represent entities in a simple hierarhical tree that is easily traversible.

info:
* usage: 
    search for an entity in the search bar, when an entity is selected it appears as top item in the list
        using the search of wikidata itself has more relevant results: (https://www.wikidata.org/wiki/Wikidata:Main_Page) 
    each entity has following parts:
        toggle symbols:
            + entity has children and can be expanded when clicked on
            . no children
            ... loading data
            ! error when fetching data
        (QID) the QID of entity, and when clicked it brings you to the Wikidata site for more information, like the linked Wikipedia articles
        (up) clicking this brings the entity to the top of the list, and shows its parents, also the url contains the QID
        description when hovered over
    clicking on entity with '+' shows the children, which can have prefix 'eg' for the examples of parent (instance_of), 'part' for parts of the parent (part_of), and no prefix means it's a subclass of parent (subclass_of) 
    checkbox 'deep search': Set limit to 50000 children (default 500). Warning: may be slow for large hierarchies
* examples:
    national cuisines with dishes: https://wikidatatree.xyz/?id=Q1968435
    minerals: https://wikidatatree.xyz/?id=Q7946
    swords: https://wikidatatree.xyz/?id=Q12791
    cell components: https://wikidatatree.xyz/?id=Q5058355
    computer science topics: https://wikidatatree.xyz/?id=Q21198
    mountains: https://wikidatatree.xyz/?id=Q8502
    Tolkien races: https://wikidatatree.xyz/?id=Q989255
    top entity: https://wikidatatree.xyz/?id=Q35120
* last fetched data on 2025-12-24 (y-m-d) from https://dumps.wikimedia.org/wikidatawiki/entities/20251222/wikidata-20251222-all.json.bz2
* processing:
    extract fields from export: 
        id, said_to_be_the_same_as, subclass_of, instance_of, part_of
        label, description, aliases: for these fields use cascade of available langauges: en > en-gb > en-ca > simple > mul > nl > ru > any other
    added entity 'ungrouped' with id 'Q7', so ungrouped entities can be accessed in tree
    fields in API:
        label: label/alias1/alias2/...
        children: subclass_of (P279) + part_of (P361) + instance_of (P31) entities
        parents: if entity has parent using same relation types as in children
        has_child: if entity has child
        relation_type: subclass_of, part_of or instance_of
* same tree but with Wikidata SPARQL queries, it has some limitations with speed and max 1min query, but is up to date (https://wikidatatree.xyz/wikidata_sparql.html)
