# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]


### Bug Fixes

- Improve pre-commit configuration ([f5ae4c8](f5ae4c833f35b1d8fa77d5ca3240772e592258cf))

- Resolve shellcheck issues in Linux installation scripts ([a83843f](a83843f0ed31cc0909f4e8acda851d84214334be))

- Ensure POSIX shell compatibility in conda removal script ([866febb](866febb349e0c1954e54b05f39d693720dfde0af))

- Ensure POSIX shell compatibility in conda removal script ([a4c9c0b](a4c9c0bb021ffbb0221c7ea60f14edb97d94dcda))

- Update Linux installation scripts with proper fixes ([5074f00](5074f00cff4d358ad0377659581c8b153ae0b3ba))

- Ignore envrc ([c32db8e](c32db8e78c8141c08ff39066244b7f67694db1f4))

- Remove unnecessary remote install ([7c9d9d4](7c9d9d4ff78a1434f9a0b3f62a4b10d4bc61952c))

- Various fixes for macos ([d80f717](d80f717ec945b825a0637751ac2861cbc21a52d7))

- Missing fish config ([87035ea](87035ea78877602cedf234613a9fbdbffc8eabcf))

- Duplicated config file ([bc85bbf](bc85bbf8afdf69350656ab75ac59e8bfbc9f979c))

- Empty fish_theme ([b461912](b46191290b0cd15b05ea779c2e02d2e919cb5f38))

- Template issue ([ffe8703](ffe870332d25d65da05e661f1e4dad7b6605f998))

- Use updated delimiters for templating ([404b26a](404b26ae18c63f7d29e57c3bfc644d01020ba1fd))

- Do not install already installed fonts ([15736ee](15736ee168fda440141a39625308f4d3b01bca96))

- Loading order of functions ([f888f00](f888f003fad74551e8973cacd83990c93ccc9886))

- Incorrect test of nbdime config ([9e92487](9e9248769d6527a92b417a48eb55a981ed389c8c))

- Incorrect test of nbdime config ([88d3525](88d3525554374cb66166d18b4c34db9b146204b1))

- Do not automatically login ([38d267a](38d267a0ccffdbe716dc0b26b3e6c4a1b6aa09c6))

- Git tools installation ([a90a8a5](a90a8a53944f3406c4a3534d757f721bf40797b3))

- Wrong variable templates ([6be8fd0](6be8fd0818d0bfe1e84dfb8acdac7532cf79a729))

- On remote server git may be blocked ([0ebd5aa](0ebd5aad9b5a641b793fac073cb033efb8490d80))

- Disable kitty mapping ([4c7f3f0](4c7f3f0f389c8238b5b456005f5fae22097488ff))

- Remove annoying nbdime message ([8196943](8196943a2565274daeea68eabd4d19d43058f23a))

- Various fixes ([de21731](de21731916a408acc8683f3ddbf0becd740c1266))

- Typo in chezmoiignore ([fc00e4c](fc00e4c84ae5236aa558c4ee130173621c54e207))

- Ensure POSIX shell compatibility in conda removal script ([60ab163](60ab1636da3b21f05201c3ddd1e7b275493114b9))

- Correct chezmoi template delimiters in conda removal script ([a739142](a739142d0150089847ae4fec40e01c4c2e480b15))

- Simplify conda removal by removing PATH manipulation ([41994cc](41994cc3eb7815dbe7316968a410d3fd46c6510e))

- Path issue ([2b65553](2b6555373f52d0273996bd3a595693488b38f5fe))

- Improve terminal compatibility and error handling ([0285cd0](0285cd0f410660ed7359474bf8c8f0de08d1cb99))

- Improve conda removal script compatibility and add proper error handling ([6fea8bb](6fea8bb36e41a9350172a9885102cc307d3b5aea))

- Simplify Python tools installation and force upgrade existing packages ([9479314](9479314fa434af401c01f538878d0b0e25a97a23))

- Improve bat handling in VS Code terminal ([4183dc7](4183dc724826e1d2e43874ea2bc9c2d9b34a9313))

- Improve neovim installation script ([dce5282](dce528243c6facf52fe501e3320cb38e4b24bf35))

- Resolve pre-commit errors in shell scripts and documentation ([769305e](769305e0fa3c66cc5f301202728e06fbedcfa797))

- Remove pyright and TypeScript language servers and fix lazy package manager errors ([f3bce99](f3bce99b2dcd528bc88780b50ef4cc0101a826e9))

- Add Git version check for conflict style compatibility ([095f309](095f3094cc9a7ecb5503b14629b4248b958de72b))

- Remove tsserver specific case from Neovim config ([21c3b67](21c3b67db2abf1d96c5c7b5c44e2465a693fc462))

- Improve 1Password CLI installation with templating and better download handling ([a8c3e15](a8c3e15232b6036746bf7fdd450819090f31aabc))

- Update gitconfig template to handle empty name and email values ([0d2e253](0d2e253b2a689e417d24a1d3fd4bb181f2dde45e))

- Update Git version detection in dot_gitconfig.tmpl ([a606cb7](a606cb734ac8ea1537e41792c1e5a7e6a6e45d64))

- Update Git version detection in dot_gitconfig.tmpl and diff configuration ([e12b781](e12b7817da43ad3af4bbe45f7430cbb005311f8a))

- Correct Git version detection with proper whitespace trimming ([d8ef554](d8ef554940efe3e6e9d7ed7423f07dd0f5c99b03))

- Only execute fish shell in interactive sessions ([ee7696b](ee7696b5d89fb3e51c599ea7185776eed5e57c00))

- Prevent ssh agent forwarding issue but unsetting SSH_AUTH_SOCK ([530a20b](530a20b33272a8fa5bdcfad3c77658fcd676c082))

- Correct WezTerm configuration comments and resolve key binding conflict ([ed5cc91](ed5cc9164b350c308e654c5d93e7eba43779fd56))

- Add brew existence check before calling brew --prefix ([434d9b3](434d9b3d676acc7230e03a8a76cbeecb039c29fa))

- Use safe treesitter folding with fallback to indent ([a38e648](a38e648c94dec5e99e93afcedf49bd37ad1d5205))

- Use mktemp for safer temporary file handling ([815ab79](815ab79e1dfac533abda155f1a00bba619737824))

- Update mason plugin name to correct GitHub organization ([53ca671](53ca6713c7c9dea3ff3874a1cf12ce7ec8bf655c))


### Chores

- Update README with recent changes ([aedab3c](aedab3c5956f7785eccb1597945eff167b2a5750))

- Update chezmoiignore patterns ([b0d5c15](b0d5c151b283d146fe4c502f12f05aa449dc7316))

- Add gitignore for generated files ([33fb917](33fb9176157657b2f04f6fac20128ae507e68695))

- Pre-push fixes ([044cc87](044cc8762df206fe283b71476db0c45db342ed48))

- Remove catppuccin fish plugin to avoid duplication with terminal theme ([25ddeec](25ddeec4747119bf3cb92f033de54d9a47c069d4))

- Better error messages ([0238912](0238912922f78b90072ade4a4a65860372375d0f))

- Add comment ([57a8122](57a81222f314a5697a1e52e7a4ee3c3b0275bc51))

- Remove unused test-variables script ([02f240b](02f240b7620848fa46267e1b983f5ffd10ddd005))

- Update fisher script and add rsync plugin ([5a63d80](5a63d803ae2d3f3da8891f26f9f7b9fe48e6edc1))


### Features

- Update README and add Git template with pre-commit hooks ([18a9e42](18a9e424e26485c793ab74eef1007d36ebe08cbd))

- Add pre-push hook for changelog generation ([5dfd99d](5dfd99d225e3d9aa474dee129f5c449f84867729))

- Add VSCode as git diff and merge tool ([73a4b0a](73a4b0a89f54fae66051ca64863309be063d513a))

- Add VSCode installation scripts with Pylance extension ([f63bfe1](f63bfe1e9d3ecb550f982a6e233f615711a6be30))

- Add Homebrew installation script and configuration ([9ba174c](9ba174ca7ee4d78c9cf0469c07587b9b6d8bc058))

- Add Google Cloud SDK installation scripts ([62b09e2](62b09e2f3a05c1b80cc411eb3ffba26e90fe3187))

- Add Nerd Fonts installation script ([e42159e](e42159e1c2a1fb6b1c29fb30f5ba166d6e8aaf8e))

- Add Docker testing infrastructure ([812f928](812f928b0c6c271d0e9ad5cd6d3518e5e84b5688))

- Add theme system with USER_THEME environment variable ([f43deb6](f43deb60fb0e0156dfedda0054fa12d252c3922d))

- Add Gruvbox Material theme support ([606b13d](606b13d95f3ba6915bd54a6551822eae1cbc7917))

- Update bat configuration for theme support ([316e955](316e95578a4b06f6094b79a00c0423cb14554cda))

- Update direnv configuration for uv support ([e84bbc9](e84bbc9b35f534a49d33e8339d999416b18b7a9a))

- Update config files for improved user experience ([621ac7f](621ac7f76b79ca2cefbb26708c3bf635d09e99dd))

- Improve Linux installation scripts for better reliability (part 1) ([223f559](223f559107a36154c654feab00605de37be4eb54))

- Add Nerd Fonts installation script ([dcae7a5](dcae7a598de3bca9e3f4c59c2638e4266f407891))

- Add Docker testing infrastructure ([3505d5b](3505d5b46c15807cba425d57f0cb50146e368ad4))

- Add theme system with USER_THEME environment variable ([224599f](224599f8f86be79de5c7bc0d4623abffdddcf222))

- Add Gruvbox Material theme support ([5f3df89](5f3df89bd1f3d18540cd54f9cea9fe3817fd08df))

- Improve uv installation script ([7058bc0](7058bc074bfd309e921780cebd77a8a99b0be669))

- Add chezmoi configuration and 1Password CLI installer ([cfa310a](cfa310aa76aaf2349de9d3cb4b4705c0d77088c5))

- Add packages data and consolidated installer for macOS ([6432480](6432480ed6a384a72b9a15e5c929311ad4495d20))

- Add test variables script and bat theme installer ([b06f625](b06f625a261dfc708abc23e5f0622932e7c5c66d))

- Add configuration for aerospace and atuin ([802f6d5](802f6d5881330c08522e61d806934eb2534586eb))

- Add 1Password SSH agent integration ([feb03e3](feb03e3f2d2428ec1923236c534b9e3d0418da4d))

- Add python tools ([1c18a1a](1c18a1ad1e928e961453af75c1a444c400c7371f))

- Add wezterm config ([7cb6170](7cb61707153395f7cc0c72ce8b59917a88294945))

- Fisher plugin manager for fish ([8f7ab2a](8f7ab2a0112aeb0e325dded058e075bb9f9be562))

- Use nvim as default editor ([720950e](720950e1641fa3e7a9cd7c2008cc16d103dab6a4))

- Remove possibly buggy agent ([18228b5](18228b5c0cea54b54ab092e07987db9a0da3fce1))

- Add 1password desktop ([8022676](80226763b28b8af0d157dafb6677d49bf57a6253))

- Remove 1password ([85c29e6](85c29e63777e044a05e16f41c51ecfc61ef59f49))

- Add github cli tool ([b158aae](b158aae92b56f9f7d309859d8de1c0b3fef75c82))

- Add doctor function for debugging ([e42c786](e42c7864065e2a0f03fc8e3f339f05af260d1800))

- Add git-extras ([d44712f](d44712ffc15d78e2263ead2cdecd1a5807dd7279))

- Uv install on linux ([9dfdc7d](9dfdc7dafe4f5163c18ab629bd1562062b171ee9))

- Re-add gitignore and changelog ([1fa0bf3](1fa0bf36aef27b935a84bb33897a9e0b0614ec8f))

- Installation of fisher for fish plugins ([e8c226e](e8c226ec90d41cddcff6da3cebb4629f826bdb64))

- Do not install already installed fonts ([435212d](435212d66c9f8b027dd3ed5dd578079a170d9d13))

- Avoid reinstalling existing themes and components ([548e503](548e503cb6906651bb0bb90b4ee82d78bad93731))

- Improve chezmoi integration ([087d833](087d8332602d7a0060a5925af7418170540357c7))

- Only install fira code font ([baae163](baae163353b1f7ca6dc39bd55bcefd6d07ebfb24))

- Improve Nerd Font installation with fast detection ([25b9407](25b9407eb630d37a0a652f53cea4d251742b239d))

- Add notebook diff config using nbdime ([731e1b8](731e1b8e2b8a677e2fe184212da764d27163b0ab))

- Shorthand for git urls ([fa63eba](fa63ebaebb11fa78c6fc8ec56ba8b7dceff30789))

- Installation updates ([a261efe](a261efe25090a1de09575a976f0873a932e7d1e2))

- Make watch-files friendlier ([f6e8534](f6e8534c623fcc7e7e6404b5ce7d79e92e735fef))

- Build neovim from source for better compatibility ([2484246](248424666f1ca8c4b47fb5381c58887075a8d9c2))

- Improve conda removal script with PATH cleaning ([ced3520](ced3520158d9527056612c80f9cae57f2a9527d9))

- Build neovim from source for better compatibility ([6ba96a4](6ba96a4ffca2349e63fb71a1b8c676e4def66de3))

- Use github cli to dynamically configure git user info ([136c9bf](136c9bf0784d8f2b32aa75dfc72e68a958e4d687))

- Make github auth mandatory for installation ([6b11b6b](6b11b6b874eb386250cdd9db94842028a551fe35))

- Improve errors handling in the script ([4fca49b](4fca49b007425a199916bb42a8e541fddac5d99f))

- Configure inline diff display for git and chezmoi ([cb9e064](cb9e064746f213ec0b9b4b9927a26bb5a4778c8e))

- Add 1password-cli to macOS packages ([e48bfa1](e48bfa1d161256c1fbbe6144621855611acf131a))

- Add 1Password CLI installation script for Linux ([850ce20](850ce20de81dec3fe548f27da46f0da603ba29e0))

- Add 1Password CLI integration to fish shell ([4f9afcc](4f9afcc321e90b131106ce04aa643052617775b4))

- Add Catppuccin Mocha as default fish theme ([fbe2fde](fbe2fdeeb811beb1e57b285ddfa4f4f2f59099dc))

- Enhance Git difftastic configuration with syntax highlighting ([bab5428](bab5428852a20aa98ab30bac00a3a718f2530480))

- Add GitHub Copilot CLI extension installation script ([91492a5](91492a55bb046f79e9aa90ed43c4cddf5328f6eb))

- Upgrade shared WezTerm configuration with enhanced settings ([4d3505b](4d3505b2f6e12436d30685f4f7832e9e95724afa))

- Update shared WezTerm config with personal config improvements ([11c6bad](11c6bad704bcf363c780ede7f44a2b424582fc72))

- Add credential helper and update merge/diff args in chezmoi config ([63ca394](63ca394d03c38dd447b4a3051cc25a45a8edae33))

- Configure Atuin sync frequency and filter mode ([2beb159](2beb1595246d9b920f2edf36bf59bc2c76b3c08f))

- Improve WezTerm TERM setting and Atuin key binding in fish config ([80ff570](80ff5705b71e7f041c766b40c21b07075ad5761d))

- Refine Git configuration with updated pager, aliases, and credential helper logic ([7a2ee4a](7a2ee4adf60777f0ff65b2ae263af44d28a2b412))

- Exclude macOS GUI configurations on SSH sessions ([75e357c](75e357cdba5111fadefbf5f04d8030f8fb455fae))


### Fix

- Set TERM consistently to xterm-256color in fish and wezterm config ([c047bfa](c047bfa48cc1306b6758dca9f492481e9867c5b4))

- Remove Catppuccin Mocha theme setting from fish config ([c3cb605](c3cb60578fb7db3170c246cadae1dd3ec6190e10))

- Update Neovim AppImage download URL to use stable release path ([6ea0933](6ea09339e120d16e508104e070cb4db0f9408aa6))


### Tests

- Enhance Docker testing infrastructure ([abc6780](abc678058ad690f1b4f3bcf1580d5d335e2bc788))


### Docs

- Add TEST.md with instructions for testing without modifying local system ([0c3b498](0c3b4988f83add15d04b57626ca554845bb74230))

- Update documentation for theme system and Nerd Fonts ([37c18c0](37c18c0d82712a17c700b4ffc2ffc38bc325e66a))

- Add contribution and tools description ([6f9de05](6f9de056af0a39a314828aa80f7bfceb715a7baa))

- Add theme switching to readme ([5897c03](5897c03435c0f84cc5c8242f33d4effe3a357807))

- Gh cli config ([09a56ae](09a56aecb1d4f552b8653f1a85a646de147f4b1a))

- Update uv description ([42be809](42be809ffbc8e8adae90f1b5bcb05d49dfd64152))

- Update the documentation ([3b8bb9f](3b8bb9fb96e5826b505aa28811b5f98877e379ec))

- Add Jupyter notebook integration documentation ([3598dd4](3598dd42e572d7f450f810f59774feefbc392046))

- Add git-extras installation and usage documentation ([1fef6eb](1fef6eb7cb04bea2690205c2f1c668c7120bea66))

- Comprehensive documentation improvements ([6181813](61818135dea7d5dcc9fdf8dc89fa2416566f4d5e))

- Update changelog ([c47990e](c47990e5cfee7168ff1a888b0174200f0e236486))

- Update readme ([031f4b2](031f4b2f2584bf38f532178665b96a1ea10b2702))

- Improve script documentation and POSIX compatibility ([3fc70b4](3fc70b472d1ea3d4fc05119cc9fb76b0d037d4a4))

- Reorganize and enhance CHEATSHEET.md ([f9e7518](f9e7518186d1263edfc1601ccab0e74bcb8a12ab))

- Update README with GitHub Copilot CLI extension information ([d9abc5c](d9abc5ccf38dc9182d2449ca4c159651206757db))

- Add development workflow guidelines to CLAUDE.md ([c5ffcaa](c5ffcaa50e050e303ea2347ea1d5b253ebfedb70))

- Add comprehensive changelog management guidelines to CLAUDE.md ([3457355](345735547e19565421055154e9ed05a3ab7ad22e))

- Update CHANGELOG with recent features and fixes ([c62a57a](c62a57a03a295a0c06de8d104bf2fbdbc3b6b299))


### Refactor

- Remove individual macOS install scripts in favor of consolidated packages ([0065b92](0065b9237ee05092f5288d85fb742db1a327f106))

- Change Git LFS to opt-in approach with template gitattributes ([fac95a5](fac95a52de3364d579f14fa1c0af3514946eccc4))

- Remove old chezmoi config file ([8eb5c08](8eb5c08877f409aee7181497f7d6bf1607ef63b8))

- Improve WezTerm installation script for SSH and terminfo ([e881005](e88100571fb2b2eb90620d7b0c243971783fec47))

<!-- generated by git-cliff -->
