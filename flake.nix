{
  description = "Prevent re-builds of derivations depending on source";
  inputs.nixpkgs.url = "nixpkgs/nixos-21.11";
  outputs = {
    nixpkgs,
    self,
  } @ inputs: let
    l = nixpkgs.lib // builtins;

    supportedSystems =
      [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

    forAllSystems = f: l.genAttrs supportedSystems
      (system: f system (import nixpkgs {
        inherit system;
      }));

  in {
    packages = forAllSystems (system: pkgs:
      let
        # pass pkgs, with ca-derivations enabled, to see change in behavior
        filteredSource = pkgs:
          pkgs.runCommand "fitlered-source" {} ''
            mkdir $out
            cp ${./.}/relevant* $out/
          '';

        # will visibly count to 9, then write the hash of filteredSource to $out
        expensive = filteredSource:
          pkgs.runCommand "expensive" {} ''
            for i in {0..9}; do
              sleep 1
              echo $i
            done
            ${pkgs.findutils}/bin/find ${filteredSource} | sha256sum > $out
          '';

        # read from `expensive` via readFile and write back to $out
        ifd = expensive:
          pkgs.runCommand "ifd" {} ''
            echo "${l.readFile "${expensive}"}" > $out
          '';
      in

      {
        # this will re-build `expensive` on any change in the source
        normal =
          let
            filteredSource' = filteredSource pkgs;
            expensive' = expensive filteredSource';
          in
            ifd expensive';

        # using a content addressed filterSource to prevent re-builds of `expensive`
        contentAddresses =
          let
            pkgsCA = import nixpkgs {
              inherit system;
              config.contentAddressedByDefault = true;
            };

            filteredSource' = filteredSource pkgsCA;
            expensive' = expensive filteredSource';
          in
            ifd expensive';

        # using builtins.path to prevent re-builds of `expensive`
        builtinsPath =
          let
            fitleredSource' = builtins.path {
              path = filteredSource pkgs;
              name = "filtered-source";
            };

            expensive' = expensive fitleredSource';
          in
            ifd expensive';
      });
  };
}
