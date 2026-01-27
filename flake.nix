{
  description = "Resume builder with Pandoc and WeasyPrint";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              pandoc
              python312Packages.weasyprint
              inter
            ];

            shellHook = ''
              echo "Resume Builder Environment"
              echo ""
              echo "Commands:"
              echo "  nix run .#pdf              - Generate resume.pdf (default)"
              echo "  nix run .#pdf -- file.md   - Generate file.pdf"
              echo "  nix run .#html               - Generate resume.html (default)"
              echo "  nix run .#html -- file.md    - Generate file.html"
              echo ""
            '';
          };
        });

      apps = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};

          fontsConf = pkgs.makeFontsConf {
            fontDirectories = [ pkgs.inter ];
          };

          buildPdf = pkgs.writeShellScriptBin "build-resume-pdf" ''
            set -e
            INPUT="''${1:-resume.md}"
            OUTPUT="''${INPUT%.md}.pdf"
            echo "Building $OUTPUT from $INPUT..."
            export FONTCONFIG_FILE=${fontsConf}
            ${pkgs.pandoc}/bin/pandoc "$INPUT" \
              --standalone \
              --css=${self}/resume-style.css \
              -o - | ${pkgs.python312Packages.weasyprint}/bin/weasyprint - "$OUTPUT"
            echo "Done! Created $OUTPUT"
          '';

          buildHtml = pkgs.writeShellScriptBin "build-resume-html" ''
            set -e
            INPUT="''${1:-resume.md}"
            OUTPUT="''${INPUT%.md}.html"
            echo "Building $OUTPUT from $INPUT..."
            ${pkgs.pandoc}/bin/pandoc "$INPUT" \
              --standalone \
              --css=${self}/resume-style.css \
              --embed-resources \
              --metadata title="Resume" \
              -H <(echo '<link rel="stylesheet" href="https://fonts.bunny.net/css?family=Inter:400,500,600,700">') \
              -o "$OUTPUT"
            echo "Done! Created $OUTPUT"
          '';
        in
        {
          pdf = {
            type = "app";
            program = "${buildPdf}/bin/build-resume-pdf";
          };

          html = {
            type = "app";
            program = "${buildHtml}/bin/build-resume-html";
          };

          default = {
            type = "app";
            program = "${buildPdf}/bin/build-resume-pdf";
          };
        });
    };
}
