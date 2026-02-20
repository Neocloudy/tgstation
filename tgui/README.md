# TGUI

## Introduction

TGUI is the robust user interface framework of /tg/station. It's very different
from other UI frameworks you'll encounter in BYOND. It's very reliant on web
technologies and JavaScript as opposed to _just_ DM.

TGUI will be easier to learn if you're familiar with any of these:
- TypeScript/JavaScript
- HTML or other XML-like languages
- NanoUI from other SS13 codebases

## Table of contents

- [TGUI](#tgui)
   * [Introduction](#introduction)
   * [Learn TGUI](#learn-tgui)
      + [Practical Tutorial](#practical-tutorial)
      + [Guides](#guides)
      + [Other Documentation](#other-documentation)
   * [Pre-requisites](#pre-requisites)
   * [Usage](#usage)
      + [Using Windows scripts](#using-windows-scripts)
      + [Using Juke Build](#using-juke-build)
      + [Using Bun](#using-bun)
   * [Dev server tools](#dev-server-tools)
      + [Dev server troubleshooting](#dev-server-troubleshooting)
         - [It's not attaching to the game](#its-not-attaching-to-the-game)
         - [It's crashing](#its-crashing)
         - [It's not finding my BYOND cache](#its-not-finding-my-byond-cache)
   * [WebView2 DevTools](#webview2-devtools)
   * [Project Structure](#project-structure)
   * [License](#license)

## Learn TGUI

People come to TGUI from different backgrounds and with different learning
styles. Whether you prefer a more theoretical or a practical approach, we hope
you’ll find this section helpful.

### Practical Tutorial

If you are completely new to frontend and prefer to **learn by doing,** start
with our [practical tutorial.](docs/tutorial-and-examples.md)

### Guides

This project uses React. Take your time to read the guide:

- [React guide](https://react.dev/learn)

If you were already familiar with an older, Ractive-based TGUI and want to
translate concepts between old and new TGUI, read this
[interface conversion guide](docs/legacy/converting-old-tgui-interfaces.md).

### Other Documentation

- [Component Reference](https://tgstation.github.io/tgui-core/?path=/docs/components-animatednumber--docs) - UI building blocks
- [tgui-core](https://github.com/tgstation/tgui-core) - The component library for TGUI.
- [Using TGUI and Byond API for custom HTML popups](docs/tgui-for-custom-html-popups.md)
- [Chat Embedded Components](docs/chat-embedded-components.md)
- [Writing Tests](docs/writing-tests.md)

## Pre-requisites

If you are using the tooling provided in this repo, everything is included! Feel
free to skip this step.

However, if you want finer control over the installation or build process, you
will need [Bun](https://bun.com/docs/installation).

## Usage

> [!IMPORTANT]
> Remember to run a full build of TGUI before submitting a PR and ensure
> all your modified files are properly formatted.
>
> Catching tooling issues yourself will save you time and commits, as you will
> not have to wait for GitHub's slow servers to point these issues out for you.
>
> In 99.9% of situations you will need to address this yourself for your PR
> to be merged into the code. The 0.1% is reserved for false positives or
> other things that are truly out of your control.

### Using Windows scripts

- `bin/tgui-build` - Build TGUI in production mode and run a full suite of code
  checks.
- `bin/tgui-dev` - Launch a development server.
  - `bin/tgui-dev --reload` - Reload byond cache once.
  - `bin/tgui-dev --debug` - Run server with debug logging enabled.

> [!NOTE]
> To open a CMD or PowerShell window in any open folder, right click **while
> holding Shift** on any free space in the folder, then click on
> *Open in Terminal* (Windows 11), *Open command window here* (Windows 10),
> or *Open PowerShell window here* (either version).

### Using Juke Build

- `tools/build/build.sh tgui` - Build TGUI in production mode.
- `tools/build/build.sh tgui-dev` - Build TGUI in production mode.
  - `tools/build/build.sh tgui-dev --reload` - Reload byond cache once.
  - `tools/build/build.sh tgui-dev --debug` - Run server with debug logging
    enabled.
- `tools/build/build.sh tgui-lint` - Show (and auto-fix) problems with the code.
- `tools/build/build.sh tgui-test` - Run unit and integration tests.
- `tools/build/build.sh tgui-analyze` - Run a bundle analyzer.
- `tools/build/build.sh tgui-clean` - Clean up TGUI folder.

> [!NOTE]
>
> With Juke Build, you can run multiple targets together, e.g.:
>
> ```
> tools/build/build.sh tgui tgui-lint tgui-tsc tgui-test
> ```

### Using Bun

Run `bun install` once to install tgui dependencies, then `cd` into the `tgui`
directory.

- `bun tgui:build` - Build tgui in production mode.
  - `bun tgui:build [options]` - Build tgui with custom webpack options.
- `bun tgui:dev` - Launch a development server.
  - `bun tgui:dev --reload` - Reload byond cache once.
  - `bun tgui:dev --debug` - Run server with debug logging enabled.
- `bun tgui:lint` - Show (and auto-fix) problems with the code.
- `bun tgui:tsc` - Check code with TypeScript compiler.
- `bun tgui:test` - Run unit and integration tests.
- `bun tgui:analyze` - Run a bundle analyzer.
- `bun tgfont:build` - Build icon fonts.

## Dev server tools

You can run the TGUI dev server using the method for your case:
[Windows](#using-windows-scripts) / [Juke Build](#using-juke-build) /
[Bun Scripts](#using-bun)

When using the dev server, you will have access to certain development only
features.

- **Hot reloading:** TGUI interfaces will update as soon as you modify them,
	saving you from having to recompile the codebase each time you modify an
	interface.
- **Debug logs:** When running the dev server, the server will print debug
	logs and time spent on rendering into the terminal. Use this information to
	optimize your code, and try to keep re-renders low, and time spent
	re-rendering as low as possible.
- **Kitchen sink:** Click the green bug on the title bar of a window to open it.
	This is a UI to view backend data without alt-tabbing to your terminal every
	few seconds.

### Dev server troubleshooting

#### It's not attaching to the game

Make sure that you have a TGUI window open before you run the dev server. Then,
once it's running, you may need to press F5 to refresh the page.

#### It's crashing

Make sure the path to your working directory doesn't contain spaces, special
unicode characters, or other symbols that upset filesystems. If so, move your
installation of the codebase to a location that doesn't have these characters.

#### It's not finding my BYOND cache

This happens if your Documents folder in Windows has a custom location, for
example in `E:\Libraries\Documents`. Development server tries its best to find
this non-standard location (searches for a Windows Registry key), but it can
fail. You have to run the dev server with an additional environmental variable,
with a full path to BYOND cache.

```env
BYOND_CACHE="E:/Libraries/Documents/BYOND/cache"
```

## WebView2 DevTools

WebView2 is [Chromium-based](https://www.chromium.org/Home/), so you can access the dev tools much easier than its
predecessor. Simply go to Debug tab in your statpanel and click "Allow Browser
Inspect". You can then press F12 or right click to access DevTools.

## Project Structure

- `/packages` - Each folder here represents a self-contained Node module.
- `/packages/common` - Helper functions that are used throughout all packages.
- `/packages/tgui/index.ts` - Application entry point.
- `/packages/tgui/interfaces` - Actual in-game interfaces.
- `/packages/tgui/layouts` - Root level UI components, that affect the final
  look and feel of the browser window. These hold various window elements, like
  the titlebar and resize handlers, and control the UI theme.
- `/packages/tgui/routes.ts` - This is where tgui decides which interface to
  pull and render.
- `/packages/tgui/styles/main.scss` - CSS entry point.
- `/packages/tgui/styles/functions.scss` - Useful SASS functions. Stuff like
  `lighten`, `darken`, `luminance` are defined here.
- `/packages/tgui/styles/atomic` - Atomic CSS classes. These are very simple,
  tiny, reusable CSS classes which you can use and combine to change appearance
  of your elements. Keep them small.
- `/packages/tgui/styles/interfaces` - Custom stylesheets for your interfaces.
  Add stylesheets here if you really need a fine control over your UI styles.
- `/packages/tgui/styles/layouts` - Layout-related styles.
- `/packages/tgui/styles/themes` - Contains themes that you can use in tgui.
  Each theme must be registered in `/packages/tgui/index.ts` file.

## License

Source code is covered by /tg/station's parent license - **AGPL-3.0** (see the
main [README](../README.md)), unless otherwise indicated.

Some files are annotated with a copyright header, which explicitly states the
copyright holder and license of the file. Most of the core tgui source code is
available under the **MIT** license.

The Authors retain all copyright to their respective work here submitted.
