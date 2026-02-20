# Tutorial and Examples

## Table of contents

- [Tutorial and Examples](#tutorial-and-examples)
   * [Main concepts](#main-concepts)
   * [Implementation](#implementation)
      + [Backend](#backend)
         - [`ui_interact`: opening your UI](#ui_interact-opening-your-ui)
         - [`ui_data`: providing data for your UI to use in rendering](#ui_data-providing-data-for-your-ui-to-use-in-rendering)
         - [`ui_act`: reacting to user input](#ui_act-reacting-to-user-input)
      + [Frontend](#frontend)
         - [Making a vaguely functional UI](#making-a-vaguely-functional-ui)
         - [JSX syntax](#jsx-syntax)
         - [Syntax examples](#syntax-examples)
         - [Splitting UIs into smaller, modular components](#splitting-uis-into-smaller-modular-components)
         - [Troubleshooting](#troubleshooting)
            * [Basic steps](#basic-steps)
            * [Blue screens](#blue-screens)
            * [Interface was not found](#interface-was-not-found)
            * [Interface is missing an export](#interface-is-missing-an-export)

## Main concepts

In DM, these are the backend procs/vars you'll most likely be interacting with.

You *must* implement at least `ui_interact` to open the UI and
*should* implement `ui_data`/`ui_static_data` if your window
needs to use data from DM.

- `proc/ui_interact`: This proc handles requests to open an interface.
  Generally, you implement (in this order): attempting to update and existing UI
  through `SStgui` -> creating a new UI if it doesn't exist -> opening the new UI.
- `proc/ui_data`: This proc handles providing JSON data to the UI each `SStgui`
  tick. In DM you write this as an associative list, and TGUI receives it as a JSON object.
- `proc/ui_static_data`: This proc is like `ui_data`, but it's not updated
  each `SStgui` tick—it's only updated when told to with `update_static_data` and
  when the UI is first opened.
- `proc/ui_act`: This proc receives user actions and reacts to them accordingly.
- `proc/ui_state`: This proc returns a `/datum/ui_state` that dictates the
  conditions for interacting with a UI.

Once the backend is complete, you create a new interface component which will
use the JSON data to render things.

## Implementation

### Backend

Let's start with something very basic. This is the "hello, world" of the TGUI
backend.

#### `ui_interact`: opening your UI
```dm
/obj/machinery/my_machine/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "MyMachine")
		ui.open()
```

This is the proc that opens or updates our interface. There's a bit going on
here, so let's break it down:

1. We actually implement the `ui_interact` proc on our object.
  This is called by the `interact` proc, which is called by `attack_hand` or
  `attack_self` for items used in-hand.
```dm
/obj/machinery/my_machine/ui_interact(mob/user, datum/tgui/ui)
```
2. Using `SStgui`, we check for an existing UI and update it if it exists.
```dm
	ui = SStgui.try_update_ui(user, src, ui)
```
3. If the UI doesn't exist, we create one and open it.
```dm
	if(!ui) // SStgui couldn't find a UI connected to this object and user
		ui = new(user, src, "MyMachine")
		ui.open()
```
You can override the UI title by providing a 4th argument, and also disable
automatic updating by calling `ui.set_autoupdate(FALSE)` after the `if(!ui)`
block.

#### `ui_data`: providing data for your UI to use in rendering
Now, we need to define `ui_data`. This returns an associative list of data
for our object to use. Let's imagine our object has a few vars:

```dm
/obj/machinery/my_machine/ui_data(mob/user)
	var/list/data = list()
	data["health"] = health
	data["color"] = color

	return data
```

`ui_data` might seem hard at first, but it's actually very simple.
You just need to represent data as numbers, strings and lists, instead
of datum/atom references.

When you do need to provide datum references to TGUI, you can do it using
`REF(datum)` which returns the memory address of a datum. More on this in
[`ui_act`: reacting to user input](#ui_act-reacting-to-user-input).

#### `ui_act`: reacting to user input
Finally, the `ui_act` proc is called by the interface whenever the user uses an
input and the frontend calls `act(action, { params })`.

The `action` and `params` are passed to `ui_act`, and you can also access
the UI object + state related to this `act`.

> [!IMPORTANT]
> The `. = ..()` (parent call) is extremely important here. It's how we know if
> the user is allowed to use this interface (to avoid "HREF exploits"). When the
> parent proc has handled the user's action already (through rejecting acts from
> nonexistent or uninteractable UIs, or something else), `.` will be `TRUE`.
>
> **Before continuing in a `ui_act` implementation, you _must_ check that `.` is
> non-null and return if so.**  Assume the user is trying to exploit the game,
> and sanitize all input in `ui_act`.
>
> If `..()` is `TRUE` you can safely assume the action has been handled already
> and should stop running, allowing the parent proc's return value to stand.

```dm
/obj/machinery/my_machine/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	switch(action)
		if("change_color")
			var/new_color = params["color"]
			if(!(color in allowed_colors))
				return FALSE
			color = new_color
			. = TRUE
	update_icon()
```

Note the use of `. = TRUE` (or `. = FALSE`/`return FALSE`).
This is used to notify the UI that the input has been handled. When `ui_act`
stops running, a `TRUE` return value tells the UI to update, and anything else
is ignored. This is important for UIs that don't auto-update, as the user
otherwise won't see the interface update based on their actions.

When you are handling a `REF` to a datum, you can get the actual reference to
that datum by using `locate(params["thing"]) in some_list`. However, your code
should be able to account for `REF` pointing to null by using the `?.` operator
or `isnull`.

```dm
// in ui_data
"item_ref" = REF(item),

// making use of it in ui_act
if("attack_item")
	var/obj/item/item = locate(params["item_reference"]) in contents // this limits the scope of it to an atom's contents, but it can still point to nothing
	item?.attack_hand(usr)
```

### Frontend

> [!NOTE]
> If you're completely new to React, you can familiarize yourself
> [here.](https://react.dev/learn/describing-the-ui)
>
> If you're completely new to TypeScript, with no JavaScript knowledge,
> you can familiarize yourself
> [here.](https://www.typescriptlang.org/docs/handbook/2/basic-types.html)
>
> New TGUI code should always be written in TypeScript/TSX.
> This section uses JavaScript/JSX for anything not specific to TypeScript/TSX.

> [!IMPORTANT]
> Remember to run a full build of TGUI before submitting a PR and ensure
> all your modified files are properly formatted.
>
> Catching tooling issues yourself will save you time and commits, as you will
> not have to wait for GitHub's slow servers to point these issues out for you.
>
> In most situations you will need to address this yourself for your PR
> to be merged. Exceptions are for false positives or other things that
> are truly out of your control.

#### Making a vaguely functional UI

Finally, let's make a React Component for your object. This part also tends to
scare away new developers, but it's very easy to get started. If you know how
HTML and JavaScript work, that will ease the learning process by quite a lot.

A React component is a wrapper for a JavaScript function,
which accepts `props` (an object of properties for component rendering) as
its argument. They are written in an XML-like structure and compiled into
function calls.

So, let's create our first component. In `tgui/packages/tgui/interfaces,`
create a file with a name `MyMachine.tsx`, and paste this snippet into it:

```tsx
import { useBackend } from '../backend';
import { Button, LabeledList, Section } from 'tgui-core/components';
import { Window } from '../layouts';

type MyMachineData = {
	health: number;
	color: string;
};

// props are skipped here because interfaces don't use them
// and it's good practice to not have completely unused args
export function MyMachine() {
	const { act, data } = useBackend<MyMachineData>();
	const { health, color } = data;
	return (
		<Window>
			<Window.Content scrollable>
				<Section title="Health status">
					<LabeledList>
						<LabeledList.Item label="Health">{health}</LabeledList.Item>
						<LabeledList.Item label="Color">{color}</LabeledList.Item>
						<LabeledList.Item label="Button">
							<Button
								content="Dispatch a 'test' action"
								onClick={() => act('test')}
							/>
						</LabeledList.Item>
					</LabeledList>
				</Section>
			</Window.Content>
		</Window>
	);
}
```

Here are the key variables you get from a `useBackend<type>()` function:

- `config` is part of core TGUI. It contains meta-information about the
  interface and who uses it, BYOND refs to various objects, and so forth.
  You are rarely going to use it, but sometimes it can be used to your
  advantage when doing complex UIs.
- `data` is the data returned from `ui_data` and `ui_static_data` procs in
  your DM code. Pretty straightforward.
  - **NOTE:** In TGUI, `data` is an object and not an array
  (because objects are the closest matching data type to BYOND associative
  lists). Array methods like `.map` and `.sort` won't work without using
  `Object.keys` or `Object.values` to get an array of keys or an array
  of values, respectively.
  - This also applies to things inside `data`. For multiple reasons
  (including object troubles), you may want to use another data
  type in `ui_data` rather than an associative list.
- `act(name, { params })` is a function which you can call to dispatch an action
  to your DM code. It will be processed in `ui_act` proc. Action name will be
  available in `params["action"]`, mixed together with the rest of parameters
  you have passed in `params` object.

#### JSX syntax

The syntax you're seeing here is called JSX. It's an extension to the core
JavaScript/TypeScript languages that allows XML-like syntax. During compilation,
XML-like syntax is turned into function calls.

Take a look at this example:

```tsx
<div className={`color-${status}`}>You are in {status} condition!</div>
```

After compiling the code above, it becomes something like this:

```js
createElement(
	'div',
	{ className: 'color-' + status },
	'You are in ',
	status,
	' condition!',
);
```

It is very important to remember that JSX is just a JavaScript expression
made out of `createElement` function calls. Naturally, this allows doing
all sorts of stuff on these expressions, just like you would with anything
else in JavaScript.

#### Syntax examples

**Conditionally render an element inside another**

This example uses the `&&` operator (the logical AND). It returns
the first operand if it evaluates to `false`, and returns the second operand
if it evaluates to `true`.

If `showProgress` is `true`, the whole expression evaluates
to a `<ProgressBar />` element. If `showProgress` is `false`, the whole
expression evaluates to `false`, and `false` is not rendered by React.

```tsx
<Box>{showProgress && <ProgressBar value={progress} />}</Box>
```

You can also use the `||` operator (the logical OR), which works the same way,
except it will return the second operand on `false` instead of `true`.

**Loop over an array to render an element for each member**

`Array.map()` is a method that calls a function for every item in the array,
and builds a new array based on what was returned by that function. You can
use this to render an element for every member in the array.

```tsx
<LabeledList>
	{items.map((item) => (
		<LabeledList.Item key={item.id} label={item.label}>
			{item.content}
		</LabeledList.Item>
	))}
</LabeledList>
```

#### Splitting UIs into smaller, modular components

You interface will eventually get really, really big. The selling point of React
is that you can split up components, and divide and conquer. Take a chunk
of your code, and wrap it into a second, smaller React component.

```tsx
import { useBackend } from '../backend';
import { Button, LabeledList, Section } from 'tgui-core/components';
import { Window } from '../layouts';

type MyMachineData = {
	health: number;
	color: string;
};

export function MyMachine() {
	return (
		<Window resizable>
			<Window.Content scrollable>
				<HealthStatus user="Jerry" />
			</Window.Content>
		</Window>
	);
}

function HealthStatus(props: { user: string }) {
	const { act, data } = useBackend<MyMachineData>();
	const { user } = props;
	const { health, color } = data;
	return (
		<Section title={'Health status of: ' + user}>
			<LabeledList>
				<LabeledList.Item label="Health">{health}</LabeledList.Item>
				<LabeledList.Item label="Color">{color}</LabeledList.Item>
			</LabeledList>
		</Section>
	);
};
```

#### Troubleshooting

##### Basic steps

- Use the [dev server](../README.md#dev-server-tools) when working with TGUI.
  It will show you compile and runtime errors in depth and allow you to edit
  interfaces without recompiling the whole codebase.
- Compile errors will cause your UI to not be updated and use the code from
  its last successful compile, so address them first if there are any
  and then refresh the window with F5.

##### Blue screens

There was an uncaught error while rendering the UI.

- Check for typos in your UI, and errors in your IDE. Not all errors will
  prevent compilation: some still allow compilation and will cause an error
  during rendering.
- Make sure your DM code is also not runtiming and has no typos,
  as that will also cause a lot of different errors.

##### Interface was not found

The interface was not found on the filesystem.

- Make sure the name of your interface on the filesystem matches the name
of the interface in the backend. If your UI is being created with its 3rd
argument as `"MedScanner"`:
  - If it's not in a folder, the name of the UI file should be `MedScanner.tsx`.
  - If it's in a folder, the folder should be named `MedScanner` and the file
  should be named `index.tsx`.

##### Interface is missing an export

The interface was found on the filesystem, but doesn't have an ES export.

- Make sure your interface has `export` prefixed behind its declaration
  and its declaration has no typos.

```tsx
export const MedScanner = () => {}

export function MedScanner() {}

export class MedScanner extends Component {}
```
