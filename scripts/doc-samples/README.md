# Doc sample compile check

`scripts/check-doc-samples.py` takes markdown files, pulls every ```dart fence
out of them, writes one library per sample into a generated package that
depends on this one by path, and runs `flutter analyze` over it. A sample that
would not compile for an integrator fails the build.

It runs over this repository's `README.md` in CI, and the docs repository runs
it on a schedule over `docs/sdks/flutter/` with this package checked out at its
released tag.

## Annotating a fence

The fence info string carries the annotation, after the language:

| Mark | Meaning | What is checked |
|---|---|---|
| (none) | A complete, copy-pasteable sample. | Analyzed as its own library. |
| `fragment` | A snippet that needs surrounding context: a few statements, a lone expression. | Analyzed, wrapped in an `async` function body. Dart has no top-level statements, which is why this mark exists. |
| `reference` | A listing of API this package provides, shown so a reader can see the shape: a class, an enum, a signature. Not for copying. | Every class and enum it names must exist in `lib/`, with the fields and values it lists; an enum listing must be complete. A signature listing must name a real function and only parameters it really takes. |
| `manifest` | An excerpt of `pubspec.yaml` or a Gradle or CocoaPods file. | Not analyzed. It is not Dart. |
| `no-compile <reason>` | Last resort. The reason is required and is printed in the census. | Nothing. |

So:

    ```dart fragment
    Relavoi.instance.events.disconnect();
    ```

`reference` is not a free pass. It is a different check, and it is the one that
would have caught `recordingEnabled` surviving in a listed `create` signature
for two releases after 0.3.0 removed it.

## Imports

The harness supplies `package:flutter/material.dart`, because a three-line
snippet does not repeat it and Flutter is not the API under test.

It supplies nothing from `package:relavoi_flutter` to a complete sample: that
import is the page's job, and keeping it the page's job is how a rename in this
package shows up as a failing doc sample. A `fragment` gets it, because a
fragment is lines out of a file that already calls the SDK.

A sample also inherits the imports shown by earlier fences on the same page,
which is the reader's situation working down a page.

## Lints

The generated package analyzes with errors only, not with this package's own
`flutter_lints` rules. A sample is written to be read: failing a page over
`prefer_const_constructors` would be noise, and noise is what makes someone
delete a check.

## The prelude

A sample is written for an app that already exists, so it reaches for symbols
this package does not provide: `myBackend`, the `_updateUi` the events page
dispatches to, a `MyApp` for `runApp`. Those are declared once in `prelude/`.

Unlike the other two SDKs, the prelude is appended into the bottom of each
generated library rather than sitting in its own file. It has to be: the docs
call private helpers like `_updateUi`, and a private name in Dart is visible
only inside its own library.

A prelude file is left out of a sample that declares a class with the file's
own name, so a page can both use a symbol and, further down, show how to write
it.

Adding to the prelude is a decision worth making deliberately: it means the
docs invented a name and the reader is expected to supply it. Keep the stub as
thin as the sample needs.
