# Automatically add @flow to your code base

This repository contains a simple bash script that will add `@flow` to the top of every JS file you ask it to, as long as doing so doesn't add flow errors to your code base.

## Usage

You probably want to run this script on all of the JS files in your git repository. Make sure you have a clean working copy, then use a command like the following:

```bash
git ls-files '*.js' | bash -c 'eval "$(curl https://raw.githubusercontent.com/CGamesPlay/add-flow-to-files/master/add_flow_to_files.sh)"'
```

You'll need to install `jq` if you don't have it, `brew install jq` should do the trick if you have a Mac.

## Why would you want to do this?

Flow is able to find errors in JS even if you don't explicitly add type information, but it will only do this for files that have `@flow` in them. If you're adding flow to a large, existing code base, simply adding `@flow` to your files now will help maximize the liklihood that adding real annotations later will expose bugs. Imagine you have the following files:

```js
// @flow
type ItemDetails = { category: string };
export type ItemPreview = { id: number, name: string };
export type Item = ItemPreview & { details: ItemDetails };
export function fetchItem(id: number): Item {
  return { id, name: "pusheen", details: { category: "cats" } };
}
export function fetchPreview(id: number): ItemPreview {
  return { id, name: "pusheen" };
}
```

```js
export default function renderItem(item) {
    return `${item.name} lives amongst ${item.details.category}`;
}
```

```js
import { fetchPreview } from './fetchItem';
import renderItem from './renderItem';
export default function myApp() {
    return renderItem(fetchPreview());
}
```

As you can see, only one of the files has had type annotations added to it. Running the script in this repository would check all 3 files:

- `fetchItem.js` already has `@flow`, so it does nothing.
- `renderItem.js` cannot have `@flow` without annotating the `item` parameter, so it does nothing.
- `myApp.js` can have `@flow` added without any errors, so the script adds it.

Later, we add type annotations to `renderItem.js`:

```js
// @flow
import type { Item } from "./testC";
export default function renderItem(item: Item) {
  return `${item.name} lives amongst ${item.details.category}`;
}
```

If you hadn't used this script, everything would type check and you would be in for a runtime bug, because an you're passing an `ItemPreview` to `renderItem`, but since it happens in an untyped file, flow doesn't notice it. If you had used this script, flow would be inferring the types in `myApp.js`, and would flag an error.
