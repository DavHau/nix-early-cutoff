## Early cutoff with and without content addressed nix

Motivated by the discussion on [haskell.nix/#1366](https://github.com/input-output-hk/haskell.nix/issues/1366), here are some exameples of how to achieve early cutoff for derivations depending on a constantly changing source.

The general problem is, that whenever a derivation depends on only some files of the source, changing any other unrelated file in the source will also trigger a re-build, as due to the input addressed nature of nix.

Therefore the general goal is to make the derivation only depend on the specific files it is interested in, not on the whole source.

Two different methods are implemented which achieve this. One using content addressing (experimental features `ca-derivations`), and the second one using `builtins.path`.


Apart from the flake and readme, this repo contains two files:
- `relevant-file` : The file which our derivation actually depends on. A change in this file `must` lead to a re-build
- `irrelevant-file` : A file which is not relevant to our derivation and therefore should `not` trigger a re-build upon change.

The flake provides the following packages:
- `normal` : demonstrating the problem
- `contantAddressed` : fix problem via ca-derivations
- `builtinsPath` : fix problem using builtins.path

All three packages are assembled like this:

`source` -> `filteredSource` -> `expensive build` -> `IFD`

The goal here is to prevent unnecessary re-builds of `expensive build`

The packages only differ in their implementation of `filteredSource`.

### Test the re-build behaviour like this:
#### 1. Execute the build to make sure the nix store is populated:
```shell
> nix build .#normal -L
...
expensive> 0
expensive> 1
expensive> 2
expensive> 3
...
```
... fine, now the `expensive` derivation has been built as expected.

#### 2. Make changes to the `irrelevant-file`
```shell
echo "xyz" >> ./irrelevant-file
```

#### 3. Build the package again
```shell
> nix build .#normal -L
...
expensive> 0
expensive> 1
expensive> 2
expensive> 3
...
```
... damn the `expensive` derivation is re-built.

Now repeat all steps but build `.#builtinsPath` or `.#contentAddressed` instead of `.#normal` and you will see that the `expensive` derivation will not be re-built after changing `irrelevant-file`.

