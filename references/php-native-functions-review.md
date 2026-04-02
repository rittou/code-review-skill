# PHP Native Functions Review

Use this reference when reviewing PHP array handling, set-like lookups, deduplication, filtering, null semantics, and combinations of built-in functions.

## Core questions

- Does the chosen native function match the data shape the code actually needs: list, lookup map, grouped structure, or filtered subset?
- Is the code preserving or discarding keys intentionally?
- Would a native function make the intent clearer or safer than a manual loop?
- Is the current composition doing unnecessary work or obscuring behavior?

## Review guidance

- Prefer the native function that matches the end state of the data, not just an intermediate transformation that happens to work.
- Call out compositions that hide key-preservation behavior, null handling, or duplicate removal semantics.
- Prefer keyed lookup structures when the code repeatedly checks for membership.
- Prefer simple list-oriented functions when the result is only iterated or returned.
- Keep the recommendation tied to behavior and readability; do not nitpick with "more native" alternatives unless they improve correctness, intent, or maintenance.

## Common patterns

### `array_fill_keys($items, true)` vs `array_values($items)`

Use `array_fill_keys()` when the result is a lookup set for repeated membership checks.

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

### `array_values(array_unique($items))` vs `array_unique(array_values($items))`

Prefer `array_values(array_unique($items))` when the goal is a deduplicated indexed list.

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
- Flag `array_unique(array_values(...))` when the earlier reindex adds no value and the caller still needs deduplicated sequential output.

### `isset($map[$key])` vs `in_array($value, $list, true)`

Use `isset()` on a keyed map for repeated membership checks.

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

### `array_filter($items)` vs `array_filter($items, fn ($item) => $item !== null)`

Use plain `array_filter()` only when removing all falsy values is intentional.

```php
$result = array_filter($items);
```

Use an explicit callback when the code should keep `0`, `'0'`, `false`, or empty strings.

```php
$result = array_filter($items, fn ($item) => $item !== null);
```

Review note:
- Flag plain `array_filter()` when the input may contain meaningful falsy values.

### `array_key_exists()` vs `isset()`

Use `isset()` when `null` should be treated like a missing or unusable value.

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

### `array_map()` vs `foreach`

Use `array_map()` when transforming each item into another value in a single expression.

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

### `array_merge($a, $b)` vs `$a + $b`

Use `array_merge()` when later string keys should overwrite earlier ones.

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
- Do we care about preserving keys?
- Is `null` different from "missing" here?
- Is this a one-off check or repeated lookup?
- Does the function chain express the final intent clearly?
