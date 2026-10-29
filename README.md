# Genesis

> ⚠️ **DISCLAIMER** <br>
> `Genesis.sh` only works for `c` projects at this moment (`Python` workspace coming soon...)

Genesis is an interactive CLI assistant (*wizard*) for 42 School students to quickly scaffold project workspaces, clone Vogsphere/GitHub repositories, generate language-specific boilerplate (C & Python), and keep your source files synchronized between the `Makefile` and the `README.md`. A configuration file lets you skip every question with a single command.

> Genesis is an independent, community-made tool. It is not affiliated with, endorsed by or sponsored by 42 or its schools

---

<details>
<summary><h2>Key features</h2></summary>

1. **Interactive CLI wizard:** launch `genesis` and answer simple prompts. Invalid answers are rejected and asked again.
2. **Fast mode:** `genesis fast` applies the values of a configuration file and asks nothing (except the project name, if you do not pass it).
3. **Configurable defaults:** the same file sets the default answer of every wizard prompt, so pressing Enter can mean *Yes* or *No* as you prefer.
4. **Three modes:**
   - **Create / Scaffold** a brand-new C or Python workspace.
   - **Fast** scaffold from the configuration file.
   - **Sync** `.c` files into the `Makefile` and `README.md` (`genesis sync`).
5. **C and Python support:**
   - **C:** optional header file (`.h`) with a valid include guard, a `Makefile` for a **program** or a **static library** (built with `ar`), header dependency tracking, and optional linking against your own `libft`.
   - **Python:** an executable `main.py` entrypoint and an empty `requirements.txt`.
6. **Non-destructive:** files that already exist (`.h`, `Makefile`, `README.md`, `main.py`) are never overwritten; the script tells you which ones it skipped. It is safe to run on a cloned repository.
7. **Clean source grouping:** `.c` files are listed 5 per line with aligned continuation lines in the `Makefile` and inside a code block in the `README.md`.
8. **Tailored documentation:** the `README.md` template covers description, architecture, usage, testing, resources and AI usage disclosure.
9. **Safe configuration:** the file is *read*, never executed (see [Configuration file](#configuration-file)).

</details>

## Requirements

- `bash`, `git`, and standard Unix tools (`awk`, `sed`, `find`)
- macOS or Linux (portable syntax, no GNU-only flags)

<details>
<summary><h2>Installation</h2></summary>

Clone the repository once and point a global alias at the script. Updating is then a simple `git pull`. Keep `genesis.conf` next to the script: that is where it is read from (symbolic links to the script are followed).

1. **Clone it:**
   ```bash
   mkdir -p ~/scripts
   git clone https://github.com/LeoDanoGG/Genesis ~/scripts/genesis
   chmod +x ~/scripts/genesis/genesis.sh
   ```

2. **Create the alias for your shell:**

   - **Zsh** (default shell on 42 Macs):
     ```bash
     echo "alias genesis='~/scripts/genesis/genesis.sh'" >> ~/.zshrc
     source ~/.zshrc
     ```

   - **Fish:**
     ```fish
     alias genesis='$HOME/scripts/genesis/genesis.sh'
     funcsave genesis
     ```
     `funcsave` persists the alias for all future sessions.

3. **Update later:**
   ```bash
   git -C ~/scripts/genesis pull
   ```
   If you edited `genesis.conf` locally, `git pull` may complain about your changes. Run `git stash` before pulling and `git stash pop` afterwards.

> 💡 **Default author:** when `AUTHOR` is empty in the configuration file, the script uses your current login (`$USER`).

</details>

## How to use

Run the command from the directory where you want the project folder to be created.

```bash
genesis                       # interactive wizard
genesis fast [name] [url]     # no questions: values come from genesis.conf
genesis default [name] [url]  # same as fast
genesis sync                  # update SRCS and the README list in the current directory
```

<details>
<summary><h3>Interactive wizard</h3></summary>

Each prompt shows its default in the hint: `[Y/n]` means Enter applies *Yes*, `[y/N]` means Enter applies *No*. Defaults come from [`genesis.conf`](#configuration-file).

1. **Action:**
   1. Create / Scaffold a new project
   2. Sync / Update `.c` files in the current directory *(Makefile & README)*
2. **Project name:** letters, digits, `.`, `_` and `-` only (no spaces or slashes).
3. **Repository setup:** local directory, or Git clone (`git@vogsphere...` / GitHub). The URL is required if you choose to clone.
4. **Author login(s):** credited in `README.md` (and in `main.py` for Python projects).
5. **Language:**
   1. C (Common Core / Piscine)
   2. Python (Common Core)
6. **C options** *(only if C is selected)*:
   - Generate `<name>.h`?
   - Generate a `Makefile`? If yes:
     - What does it build? **Program** (executable) or **Static library** (`.a`, built with `ar`)
     - Link against your own `libft` (`./libft`)?
7. **Documentation:** generate `README.md`?

If you cloned a repository that already contains `.c` files in its root, they are added to `SRCS` and to the README list automatically.

</details>

### Fast mode

```bash
genesis fast ft_printf
genesis fast push_swap git@vogsphere.42madrid.fr:...
genesis fast                 # asks only for the project name
```

Every other answer is taken from `genesis.conf`. If you give a URL as the second argument, the repository is cloned instead of creating a local folder. A one-line summary of the applied settings is printed before anything is created.

### Syncing existing projects

Once you have added or removed `.c` files in your project root, you do not need to edit `SRCS` or the README list by hand:

```bash
cd my_project
genesis sync
```

*(Or run `genesis` and choose option 2.)*

The script scans for `.c` files, groups them 5 per line, and rewrites only what is **between the markers**:

| File			| Start marker				| End marker			|
|---------------|---------------------------|-----------------------|
| `Makefile`	| `# SRCS_START`			| `# SRCS_END`			|
| `README.md`	| `<!-- FILES_START -->`	| `<!-- FILES_END -->`	|

If a file or its markers are missing, that file is skipped with a warning and nothing else is touched. Running sync repeatedly gives the same result. It works the same for programs and static libraries.

> If you cloned a repository that already had its own `README.md`, the script will not overwrite it. To use sync with it, add the two README markers wherever you want the list to appear.

<details>
<summary><h3>Configuration file</h3></summary>

`genesis.conf`, located next to the script, is used by both fast mode and the wizard defaults.

```ini
AUTHOR=
LANGUAGE=c
PROJECT_TYPE=program
GENERATE_HEADER=y
GENERATE_MAKEFILE=y
USE_LIBFT=n
GENERATE_README=y
```

| Key					| Values									| Meaning										|
|-----------------------|-------------------------------------------|-----------------------------------------------|
| `AUTHOR`				| letters, digits, `. _ , -` and spaces		| Author login(s). Empty = your `$USER`.		|
| `LANGUAGE`			| `c` \ `python`							| Language of the new project.					|
| `PROJECT_TYPE`		| `program` \ `library`						| What the C `Makefile` builds.					|
| `GENERATE_HEADER`		| `y` \ `n`									| Generate `<name>.h` (C only).					|
| `GENERATE_MAKEFILE`	| `y` \ `n`									| Generate a `Makefile` (C only).				|
| `USE_LIBFT`			| `y` \ `n`									| Use the `libft` template in the `Makefile`.	|
| `GENERATE_README`		| `y` \ `n`									| Generate `README.md`.							|

Example: with `GENERATE_README=n`, the wizard prompt becomes `[y/N]` and fast mode skips the README. `y`/`yes` and `n`/`no` are accepted in any case.

#### Why it is safe

The file is **read line by line, never executed**: the script does not use `source` or `eval`. Only the keys above are accepted, each value is checked against its allowed set, and anything else (unknown keys, malformed lines, shell syntax such as `$(...)` or backticks) is ignored with a warning. The same applies to author logins typed in the wizard. Repository URLs are passed to `git clone` after `--`, so a URL can never be interpreted as a git option.

If the file is missing, built-in defaults are used (the same as the example above).

</details>

<details>
<summary><h3>Makefile options</h3></summary>

#### Program or static library

- **Program:** `NAME` is the project name and the `Makefile` links the objects into an executable.
- **Static library:** `NAME` is a `lib<name>.a` archive built with `ar rcs`. The name is derived from the project name: `ft_printf` → `libftprintf.a`, `libft` → `libft.a`. Edit `NAME` if your subject requires something else.

With the library type **and** the `libft` option, the `Makefile` first copies `libft.a` to `NAME` and then adds your objects with `ar rcs`, so the final archive contains both your code and libft. Without `libft`, it only archives your objects. Check the subject of your project for the exact requirements (name, allowed tools and whether it must include libft).

#### About the header option

Say **no** to the header when a cloned repository already ships its own. The `Makefile` links the header as a dependency of every `.o` file through the `HEADER` variable, which is filled in only if `<name>.h` actually exists. If it does not (for example, your header has another name), `HEADER` is left empty and `make` keeps working; set it by hand to the right file so that editing it triggers a recompilation.

#### About the `libft` option

The generated `Makefile` expects your library in `./libft`, with its own `Makefile` producing `libft.a`. Copy the **sources, its `Makefile` and `libft.h`** (not the `.o` / `.a` files, and without a nested `.git` folder).

- It adds `-I./libft`, so you can write `#include "libft.h"`.
- If `libft/libft.a` does not exist, `make` builds it with `make -C libft` before linking (or archiving).
- `clean`, `fclean` and `re` are propagated to libft as well.
- A second `make` with nothing changed does nothing.

**If you edit libft while working on the project**, `make` will not notice, because `libft.a` already exists. Run `make -C libft` (or `make re`) to pick up the changes. In an evaluation this is not an issue, since the repository is cloned and built from scratch.

#### Using a different library

The `libft` option is a **template**. If you need another library with the same layout (a folder with its own `Makefile` that builds a `.a`), generate the project with this option and then edit the generated `Makefile` by hand. A comment above the variables reminds you of where:

| What								| Where							| Example 					|
|-----------------------------------|-------------------------------|---------------------------|
| Folder							| `LIBFT_DIR`					| `./mylib`					|
| Archive name 						| `LIBFT`						| `$(LIBFT_DIR)/libmylib.a`	|
| Link flag *(program type only)*	| `-lft` in the `$(NAME)` rule	| `-lmylib`					|

The rules (`make -C`, `clean`, `fclean`) and include path (`-I`) follow `LIBFT_DIR`, so they need no changes.

Libraries that need more than that, such as MiniLibX (extra system flags, its own build process), are **not** covered by the template: check the subject and add the flags yourself.

</details>

---

## Limitations

- Sync only scans the **project root** (no subdirectories such as `src/`).
- Sync only handles **`.c` files**. Python projects do not use markers.
- Every `.c` in the root is listed, including test files such as a throwaway `main.c`. Remove them before syncing if the subject does not allow them (a static library usually must not contain a `main`).
- Anything you write between the markers is replaced on the next sync. Keep your own notes outside of them.
- The configuration file is always read from the folder of the script; there is no per-project configuration.

---

## Important reminders

> ⚠️ **Preserve the markers.** Do not delete or rename `# SRCS_START` / `# SRCS_END` in the `Makefile` or `<!-- FILES_START -->` / `<!-- FILES_END -->` in the `README.md`.

> ⚠️ **Makefile tabs.** Recipe lines must start with a real TAB. If you edit the generated `Makefile` and get `missing separator`, your editor probably converted tabs into spaces.

> ⚠️ **Check the subject.** The generated files are a starting point. Always verify the final `Makefile` and `README.md` against the requirements of your specific project.
