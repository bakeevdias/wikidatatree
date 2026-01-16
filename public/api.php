<?php
/**
 * Wikidata PHP SQLite API
 * 
 * Endpoints:
 * - GET /api.php?action=search&q=text&limit=10
 * - GET /api.php?action=hierarchy&id=Q42&limit=10&fields=entity,parents
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

// Database connection
try {
    $dbPath = __DIR__ . '/../data/wikidata.db';
    $pdo = new PDO('sqlite:' . $dbPath);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    http_response_code(500);
    die(json_encode(['error' => 'Database connection failed']));
}

// Get action from query string
$action = $_GET['action'] ?? '';

switch ($action) {
    case 'search':
        handleSearch($pdo);
        break;
    
    case 'hierarchy':
        handleHierarchy($pdo);
        break;
    
    default:
        http_response_code(400);
        echo json_encode(['error' => 'Invalid action. Use: search or hierarchy']);
}

/**
 * Endpoint 1: Text search in labels
 * Returns top 100 entities with matching labels
 */
function handleSearch($pdo) {
    $query = $_GET['q'] ?? '';
    
    if (empty($query)) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing query parameter: q']);
        return;
    }
    
    // Escape full-text search special characters
    $query = trim($query);
    $query = str_replace(' ', '-', $query); // Replaces all spaces with hyphens.
    $query = preg_replace('/[^A-Za-z0-9\-]/', '', $query); // Removes special chars.
    $query = preg_replace('/-+/', ' ', $query); // Replaces multiple hyphens with single space.
    
    if (empty($query)) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid query']);
        return;
    }
    
    
    
    $limit = 100;
    if (isset($_GET['limit']) && ctype_digit($_GET['limit'])) {
        $limit = (int) $_GET['limit'];
    }
    
    $stmt = $pdo->prepare("
        WITH hits AS (
        	SELECT rowid
        	FROM entity_text_fts
        	WHERE entity_text_fts MATCH :match
        	LIMIT :limit
        )
        SELECT e.id, e.label, e.description
        FROM hits
        JOIN entity_text_fts e ON e.rowid = hits.rowid
        ORDER BY
            (e.description IS NULL OR e.description = ''),
            (e.description GLOB '[0-9]*'),
            e.description COLLATE NOCASE,
            e.label COLLATE NOCASE;
        LIMIT :limit;
    ");
    $stmt->bindValue(':match', 'label:' . $query . '*', PDO::PARAM_STR);
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->execute();
    $results = $stmt->fetchAll();
    echo json_encode($results);
}

/**
 * Endpoint 2: Get entity hierarchy
 * Returns parents and direct children
 */
function handleHierarchy($pdo) {
    $id = $_GET['id'] ?? '';
    if (empty($id)) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing parameter: id']);
        return;
    }
    
    $limit = 500;
    if (isset($_GET['limit']) && ctype_digit($_GET['limit'])) {
        $limit = (int) $_GET['limit'];
    }
    
    $fields = ['entity','parents','children'];
    if (isset($_GET['fields'])) {
        $input_fields = explode (',', trim((string) $_GET['fields']));
        $input_fields = array_intersect($fields, $input_fields);
        $fields = empty($input_fields) ? $fields : $input_fields;
    }

    
    
    
    if (in_array('entity', $fields, true)) {
        $stmt = $pdo->prepare("
            SELECT t.id, t.label, t.description, d.has_child
            FROM (
                SELECT * FROM entity_text WHERE id = :id
            ) t
            JOIN entity_data d ON d.id = t.id;
        ");
        
        $stmt->execute(['id' => $id]);
        $entity = $stmt->fetch();
        
        if (!$entity) {
            http_response_code(404);
            echo json_encode(['error' => 'Entity not found']);
            return;
        }   
    }

    if (in_array('parents', $fields, true)) {
        $parents = [];
        
        // subclass_of
        $stmt = $pdo->prepare("
            SELECT t.id, t.label, t.description, 'subclass_of' as relation_type
            FROM (
                SELECT subclass_of
                FROM subclass_of
                WHERE id = :id
                LIMIT :limit
            ) c
            JOIN entity_text t ON c.subclass_of = t.id
            ORDER BY t.label COLLATE NOCASE;
        ");
        $stmt->execute([
            'id' => $id, 
            'limit' => $limit
        ]);
        $parents = array_merge($parents, $stmt->fetchAll());
        
        
        // part_of
        $stmt = $pdo->prepare("
            SELECT t.id, t.label, t.description, 'part_of' as relation_type
            FROM (
                SELECT part_of
                FROM part_of r
                WHERE id = :id
                LIMIT :limit
            ) c
            JOIN entity_text t ON c.part_of = t.id
            ORDER BY t.label COLLATE NOCASE;
        ");
        $stmt->execute([
            'id' => $id, 
            'limit' => $limit
        ]);
        $parents = array_merge($parents, $stmt->fetchAll());
        
        
        
        // instance_of
        $stmt = $pdo->prepare("
            SELECT t.id, t.label, t.description, 'instance_of' as relation_type
            FROM (
                SELECT instance_of
                FROM instance_of r
                WHERE id = :id
                LIMIT :limit
            ) c
            JOIN entity_text t ON c.instance_of = t.id
            ORDER BY t.label COLLATE NOCASE;
        ");
        $stmt->execute([
            'id' => $id, 
            'limit' => $limit
        ]);
        $parents = array_merge($parents, $stmt->fetchAll());
    }

    
    if (in_array('children', $fields, true)) {
        $children = [];
        
        // subclass_of (children are entities that are subclasses of this entity)
        $stmt = $pdo->prepare("
            SELECT t.id, t.label, t.description, d.has_child, 'subclass_of' as relation_type
            FROM (
                SELECT id
                FROM subclass_of r
                WHERE subclass_of = :id
                LIMIT :limit
            ) c
            JOIN entity_text t ON t.id = c.id
            JOIN entity_data d ON d.id = c.id
            ORDER BY t.label COLLATE NOCASE;
        ");
        $stmt->execute([
            'id' => $id, 
            'limit' => $limit
        ]);
        $children = array_merge($children, $stmt->fetchAll());
        
        
        // part_of (children are entities that are parts of this entity)
        $stmt = $pdo->prepare("
            SELECT t.id, t.label, t.description, d.has_child, 'part_of' as relation_type
            FROM (
                SELECT id
                FROM part_of r
                WHERE part_of = :id
                LIMIT :limit
            ) c
            JOIN entity_text t ON t.id = c.id
            JOIN entity_data d ON d.id = c.id
            ORDER BY t.label COLLATE NOCASE;
        ");
        $stmt->execute([
            'id' => $id, 
            'limit' => $limit
        ]);
        $children = array_merge($children, $stmt->fetchAll());
        
        
        
        // instance_of (children are entities that are instances of this entity)
        $stmt = $pdo->prepare("
            SELECT t.id, t.label, t.description, d.has_child, 'instance_of' as relation_type
            FROM (
                SELECT id
                FROM instance_of r
                WHERE instance_of = :id
                LIMIT :limit
            ) c
            JOIN entity_text t ON t.id = c.id
            JOIN entity_data d ON d.id = c.id
            ORDER BY t.label COLLATE NOCASE;
        ");
        $stmt->execute([
            'id' => $id, 
            'limit' => $limit
        ]);
        $children = array_merge($children, $stmt->fetchAll());
    }

    $response = [];
    if (in_array('entity', $fields, true)) $response['entity'] = $entity;
    if (in_array('parents', $fields, true)) $response['parents'] = $parents;
    if (in_array('children', $fields, true)) $response['children'] = $children;
    echo json_encode($response);

}

?>