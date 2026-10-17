# Unity assets carry over as placeholders only

The GDD's Visuals section is open and art direction is out of scope for the migration, so nothing that comes across from the Unity prototype commits Rubbley's look. The future art-direction map replaces or confirms each one. Only one file carries over as an asset: `asteroid-lowpoly.fbx` (original work), converted once to `.glb` and committed into the Godot project's asset folder. The repo-layout decision sets the exact path. Everything else is rebuilt in Godot rather than ported: the toon look, the background, materials, prefabs, debug scenes and the camera preset. The Unity files stay only as behaviour and tuning reference until Unity is retired.

## Considered Options

- **Import the FBX directly** (Godot's ufbx importer): rejected. glTF is Godot's first-class format, and a one-off conversion avoids FBX import quirks.
- **Port `Toon.shader` to a Godot `spatial` shader**: rejected for now. Placeholders use `StandardMaterial3D` with the built-in Toon diffuse and specular modes plus rim, which gets close to the prototype's look with no custom code. The original is adapted from Roystan's UnityToonShader, which is under the Unlicense, so the art-direction map can still port it freely.
- **Carry over the Starfield Skybox**: rejected. Its six 16-bit 4096² faces (about 300 MB) are far too heavy for phones, and a top-down camera barely shows the sky.

## Consequences

- The placeholder background is a procedural starfield: points of light generated from noise, drawn on several layers that scroll at different rates against the `CameraRig` to give parallax. It uses no texture assets. It is a placeholder, not design intent.
- The Starfield Skybox (Pulsar Bytes, Unity Asset Store, Standard EULA) was deleted from the Unity tree. The EULA allows using it with another engine but bars redistributing the raw files, and this repo is public. It remains in git history: we chose not to rewrite history, because a purge would force every clone and branch to re-sync and still couldn't reach GitHub's PR refs.
- With the skybox gone, the Unity debug scenes render without a sky. That doesn't affect their use as behaviour reference.
- The `Bouncy` physics material's values are tuning reference for the tuning-data decision, not an asset to port.
