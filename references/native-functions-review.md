# Native Functions Review

Use this reference when reviewing standard-library and native-function choices across languages, especially for collection handling, set-like lookups, deduplication, filtering, null semantics, and function composition.

## Core questions

- Does the chosen native function match the data shape the code actually needs: list, lookup set, keyed map, grouped structure, or filtered subset?
- Is the code preserving or discarding keys intentionally?
- Would a native function make the intent clearer or safer than a manual loop?
- Is the current composition doing unnecessary work or obscuring behavior?

## Review guidance

- Prefer the native function that matches the end state of the data, not just an intermediate transformation that happens to work.
- Call out compositions that hide key-preservation behavior, null handling, or duplicate removal semantics.
- Prefer keyed lookup structures when the code repeatedly checks for membership.
- Prefer simple list-oriented functions when the result is only iterated or returned.
- Keep the guidance language-aware: the same principle may appear as `array_*` in PHP, `set` or list comprehensions in Python, `Set` or `Object` helpers in JavaScript, or stream/collection APIs elsewhere.
- Keep the recommendation tied to behavior and readability; do not nitpick with "more native" alternatives unless they improve correctness, intent, or maintenance.

## Common patterns

### Lookup set or map vs plain list

Use a lookup-oriented native structure when the result is used for repeated membership checks.

Examples:
- PHP: `array_fill_keys($items, true)`
- Python: `set(items)`
- JavaScript: `new Set(items)` or an object/map when keyed access is clearer

Use a list-oriented native function when the code only needs a plain sequence for iteration or output.

Examples:
- PHP: `array_values($items)`
- Python: `list(items)`
- JavaScript: `Array.from(items)` or direct array use when already sequential

PHP example:

```php
$allowedIds = array_fill_keys($ids, true);

if (isset($allowedIds[$id])) {
    // membership check
}
```

Use `array_values()` when the code only needs a plain indexed list.

```php
$list = array_values($items);
```

Review note:
- A set-like map is better when the next operation is `isset($map[$value])`.
- A reindexed list is better when the result is only looped over, returned, or serialized.

### Deduplicate first, then normalize the output shape

Prefer the function order that performs deduplication first and only then reshapes the result into the final output form.

Examples:
- PHP: `array_values(array_unique($items))`
- Python: `list(dict.fromkeys(items))` when order must be preserved
- JavaScript: `Array.from(new Set(items))`

PHP example:

```php
$uniqueItems = array_values(array_unique($items));
```

Why:
- `array_unique()` preserves the original keys.
- `array_values()` should usually come after deduplication when the caller expects sequential indexes.

```php
$items = [2 => 'a', 5 => 'b', 9 => 'a'];

array_unique($items);
// [2 => 'a', 5 => 'b']

array_values(array_unique($items));
// ['a', 'b']
```

Review note:
- Flag compositions where an earlier reshape adds no value before deduplication or makes later behavior harder to reason about.

### Key existence or membership check vs linear search

Use key existence or set membership when the code checks the same collection repeatedly.

Examples:
- PHP: `isset($map[$key])`
- Python: `key in mapping` or `value in set_values`
- JavaScript: `set.has(value)` or `Object.hasOwn(obj, key)`

Use linear search when the check is one-off and the code already has a simple list.

Examples:
- PHP: `in_array($value, $list, true)`
- Python: `value in items`
- JavaScript: `array.includes(value)`

PHP example:

```php
$userIdSet = array_fill_keys($userIds, true);

if (isset($userIdSet[$userId])) {
    // preferred for repeated lookups
}
```

Use `in_array()` for occasional checks when the code already has a list.

```php
if (in_array($userId, $userIds, true)) {
    // acceptable one-off check
}
```

Review note:
- Recommend the map form when membership testing happens in loops or hot paths.
- Keep `in_array()` when introducing a temporary map would complicate otherwise simple code.

### Default filtering vs explicit predicate

Use the default filter behavior only when removing all falsy values is intentional.

Examples:
- PHP: `array_filter($items)`
- Python: `filter(None, items)`
- JavaScript: `items.filter(Boolean)`

Use an explicit predicate when the code should keep meaningful falsy values such as `0`, `false`, or empty strings.

Examples:
- PHP: `array_filter($items, fn ($item) => $item !== null)`
- Python: `[item for item in items if item is not None]`
- JavaScript: `items.filter((item) => item !== null)`

PHP example:

```php
$result = array_filter($items);
```

Use an explicit callback when the code should keep `0`, `'0'`, `false`, or empty strings.

```php
$result = array_filter($items, fn ($item) => $item !== null);
```

Review note:
- Flag plain `array_filter()` when the input may contain meaningful falsy values.

### Distinguish null from missing when the language makes that possible

Use the native function that matches the domain rule for "missing" versus "present with a null value".

Examples:
- PHP: `array_key_exists()` vs `isset()`
- JavaScript: `Object.hasOwn(obj, key)` vs truthy checks
- Python: `'key' in data` vs `data.get('key') is not None`

PHP example:

```php
if (isset($data['name'])) {
    // value exists and is not null
}
```

Use `array_key_exists()` when `null` is a valid stored value.

```php
if (array_key_exists('name', $data)) {
    // key exists even if value is null
}
```

Review note:
- This distinction matters in payload normalization, patch semantics, and partial updates.

### Transformation pipeline vs explicit loop

Use map-like native functions when transforming each item into another value in a single, readable step.

Examples:
- PHP: `array_map(...)`
- Python: list comprehensions or `map(...)`
- JavaScript: `array.map(...)`

Use an explicit loop when the logic needs branching, side effects, early exits, or multi-step normalization.

PHP example:

```php
$names = array_map(fn ($user) => $user['name'], $users);
```

Use `foreach` when the logic needs branching, side effects, or multi-step normalization.

```php
$names = [];
foreach ($users as $user) {
    if (!isset($user['name'])) {
        continue;
    }

    $names[] = trim($user['name']);
}
```

Review note:
- Prefer the form that keeps the control flow obvious instead of forcing everything into a callback.

### Merge or union semantics must match override behavior

Use the native merge operation that matches the intended precedence and key behavior.

Examples:
- PHP: `array_merge($a, $b)` vs `$a + $b`
- Python: `{**a, **b}` or `a | b`
- JavaScript: `{...a, ...b}`

PHP example:

```php
$result = array_merge($defaults, $overrides);
```

Use `$a + $b` when existing keys from the left-hand array should win.

```php
$result = $overrides + $defaults;
```

Review note:
- These are not interchangeable; call out mistaken use when fallback or override precedence changes behavior.

## Rule of thumb

Ask these during review:

- Do we need a list or a lookup map?
- Are we choosing this function because it matches the final shape, or only because it was nearby?
- Do we care about preserving keys?
- Is `null` different from "missing" here?
- Is this a one-off check or repeated lookup?
- Does the function chain express the final intent clearly?
