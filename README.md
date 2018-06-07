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

## How effective is this?

Since it only adds annotations which don't cause flow errors, this script will never identify any type safety violations by itself. The idea is simply to make it more likely that a future developer will.

I manage a code base with around 560 JS files weighing in at around 38k LOC. Before running this script, 62 files had manually been annotated for flow. This script was able to add `@flow` to exactly 100 files without causing any new errors.

The files that it annotated were mostly vacuous `index.js` files that just do `export * from './actions'; export * from './reducers';` which means that developers who actually go and add type annotations to the actions and reducers files are much more likely to expose real errors.

One of the more interesting places where the script was able to run was several of our redux connected components. When we go and add type checking to our selectors, Flow will be able to type check the `mapStateToProps` functions already. Note that flow cannot infer the types of a function parameter by looking at the call sites (it does the opposite, inferring the return type by looking at the function body), so the actual render methods of these components still need to have types added to them manually.