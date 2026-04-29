# Deploying the Godot Web Export to Vercel

This repository is a Godot project. Vercel can serve the exported web files, but it cannot deploy the raw `project.godot` project as a website.

## Export from Godot

1. Open `more-nstuffthursday/project.godot` in Godot 4.5.
2. Open `Project > Export`.
3. Select the `Web` preset.
4. If Godot asks for export templates, install them.
5. Export to:

   ```text
   more-nstuffthursday/web/index.html
   ```

Commit the generated `more-nstuffthursday/web` folder before deploying from Git.

## Vercel Settings

If the Vercel project root is the repository root, the root `vercel.json` serves:

```text
more-nstuffthursday/web
```

If the Vercel project root is set to `more-nstuffthursday`, the nested `more-nstuffthursday/vercel.json` serves:

```text
web
```

Leave the build command and install command empty. The Godot export should already exist before Vercel deploys.

## Why the 404 Happened

The Vercel `NOT_FOUND` page means the requested deployment or resource was not available. In this project, the likely cause was that Vercel had no `index.html` or configured output directory to serve. Exporting the Godot Web build and pointing Vercel at that folder gives Vercel a real static site entrypoint.
