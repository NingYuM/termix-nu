# Setup pnpm store
just clean; just store -i
# Generate ali* node modules list
source tools/store.nu; get-alife-modules | to yaml | save tools/ali-pkgs.yaml

t dir-batch-exec "'ls pkgs | length'" acrm-ui,asrm-ui,bulma-ui,carbon-ui,csp-portal-ui,ep-ui,imall-ui,buyer-h5

# Clear Husky config
rg husky -C 3
ls pkgs/ | get name | each {|it| let pkg = open $'($it)/package.json' | reject -i husky; $pkg | save -f $'($it)/package.json' }
cd .git/hooks; rg husky --files-with-matches | lines | rm ...$in

# Add assets script after building assets
ls pkgs/ | get name | each {|it| let pkg = open $'($it)/package.json' | upsert scripts.build {|it| if not ($it.scripts.build =~ 'assets.nu') { $'($it.scripts.build) && nu ../../tools/assets.nu' } else { $it.scripts.build } }; $pkg | save -f $'($it)/package.json' }

# Add assets release version for each package
ls pkgs/ | get name | each {|it| let pkg = open $'($it)/package.json' | upsert distVersion '1.0.0'; $pkg | save -f $'($it)/package.json' }

# Remove f2elint deps
ls pkgs/ | get name | each {|it| let pkg = open $'($it)/package.json' | reject -i devDependencies.f2elint; $pkg | save -f $'($it)/package.json' }

# 依赖检查
let pkgs = ls pkgs/ | get name | each {|it| open $'($it)/package.json' | get name }
for n in $pkgs { print $'(char nl)($n)(char nl)-----------------------------'; rg $n pkgs/*/package.json }

# Copy missing packages
let repoRoot = '/Users/hustcer/github/term-o/csp_fe_repos'
open -r tools/pkgs.yaml | lines | each {|it| $'($repoRoot)/($it)' | path exists }
open -r tools/pkgs.yaml | lines | each {|it| cp -r $'($repoRoot)/($it)' pkgs/ }

# Ignore warning of "Using / for division outside of calc() is deprecated"
glob pkgs/**/*/rsbuild.config.ts | each {|it| open $it | str replace 'plugins:' (open ttt) | save -rf $it }
