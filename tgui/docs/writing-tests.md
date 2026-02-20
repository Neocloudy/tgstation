# Writing tests
Using Bun and Jest/React Testing Library you can unit test interfaces and libraries.

## Table of contents

- [Writing tests](#writing-tests)
   * [Mocks](#mocks)
   * [Normal tests (non-interfaces)](#normal-tests-non-interfaces)
   * [Interfaces](#interfaces)

## Mocks
You can modify modules and interfaces specifically for tests by creating a file
in `tgui/__mocks__`, overriding the module/interface as needed and calling
`mock.module` at the end, specifying the module to override and factory
of exports to mock.

For example, to modify the `Window` component to have predictable props:

```tsx
type WindowProps = Partial<{
  title: string;
}>;

function Window(props: PropsWithChildren<WindowProps>) {
  const { title = 'Test UI', children } = props;

  return (
    <div className="Window">
      <div>{title}</div>
      {children}
    </div>
  );
}

function Content(props: PropsWithChildren) {
  const { children } = props;

  return <div className="Window__content">{children}</div>;
}

Window.Content = Content;

mock.module('../layouts', () => ({
  Window,
  Layout: Window,
  Pane: Window,
}));
```

## Normal tests (non-interfaces)
Create a file named `[filetotest].test.[ts|js]`. It should be named after the
library it's meant to test for organization purposes, but it's not required.

In your test file, call `describe` with a label to describe a group of related
tests and the function that defines the tests.

```ts
import { describe } from 'bun:test';

describe('dumb_test', () => {/* ... */})
```

You can then add tests to the group by calling `it` with a description of
what should happen, and a test function.

The test function should *at least* call `expect` with a value, and chain
[Matcher functions](https://jest-extended.jestcommunity.dev/docs/matchers/) on.

```ts
import { describe, expect, it } from 'bun:test';

describe('dumb_test', () => {
  it('should always work', () => {
    expect(false).toBe(false);
  });
  it('should always fail', () => {
    expect(true).toBe(false);
  });
});
```

## Interfaces
This is mostly the same as making a normal test.

Suppose you're writing a test for the `Radio` interface.

Before even declaring your test, modify the backend data as needed,
and to something predictable:

```ts
store.set(gameDataAtom, {
  freqlock: 0,
  frequency: 1553,
  minFrequency: 1200,
  maxFrequency: 1600,
  listening: 1,
  broadcasting: 0,
  command: 0,
  useCommand: 1,
  subspace: 0,
  subspaceSwitchable: 1,
  channels: {},
  radio_noises: 0,
});
```

Now, you can declare your test groups, and in each individual test, call
`act` + `render` to fake-render your interface into a container.

You can then access `screen`'s many query functions to check that text
exists in the document, for example:

```tsx
describe('Radio tests', () => {
  it('loads without failing', () => {
    act(() => render(<Radio />));

    // Radio doesn't have a default title
    expect(screen.getByText('Test UI')).toBeDefined();
  });

  it('displays frequency correctly', () => {
    act(() => render(<Radio />));

    expect(screen.getByText('155.3')).toBeDefined();
  });
});
```
