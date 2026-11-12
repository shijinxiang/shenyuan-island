Low Poly Skies Free
===================

4 stylized low-poly skyboxes and 10 sky props taken from Low Poly Skies (24 skyboxes and 38
props: clouds that drift, rain and snow, suns, moons, stars, an aurora, storms and seasons, and
a viewer to switch them): https://heyheythere.itch.io/low-poly-skies
The skies: a fair day, an orange sunset, a full moon night and a grey overcast. The props: a
small cumulus, a cumulus, a cloud bank, a storm cloud, a sun, a crescent moon, a star, a rainbow,
a lightning bolt and a meadow square. One 1024x1024 texture atlas, a glow map for the lit props,
real-world scale (1 unit = 1 metre).

What's in the zip
-----------------
skies/      panoramas/<sky>.png, each sky equirectangular, 4096x2048;
            cubemaps/<sky>/px nx py ny pz nz.png, its cube map, 1024 a face, +Y up, -Z ahead
            (OpenGL's order and orientation, as a glTF scene has them);
            skies.json, each sky's title, kind and light (below)
glb/        one file per prop, with its animations (the best format for Godot, Blender, three.js)
fbx/        one file per prop, with its animations as takes (Unreal, Unity, most 3D apps)
obj/        one file per prop, still (any 3D app)
textures/   atlas.png, the one texture every prop uses, and atlas_glow.png, its glow
icons/      an icon per prop, 256x256 PNG with transparency
props.json  every prop: title, group, size, triangles, parts and animations
blender/    every prop in one .blend, the atlas packed in
addons/     the Godot addon, low_poly_skies/: this folder is a Godot 4.3+ project that opens on
            the skies' viewer (.gdignore keeps Godot out of the other folders)

A sky's light
-------------
skies.json gives each sky's sun or moon: "to", the direction toward it in a +Y up, -Z ahead space
(the cube maps' and glTF's), "az" and "el" (degrees round from north and above the horizon),
"color", "energy" (1 is a clear day's sun) and "moon"; "ambient", a colour for the ambient light,
and "fog", the horizon's colour, for a fog that fades a scene into the sky. Point your
directional light along -"to".

The panoramas are in Blender's equirectangular layout: the middle column looks along +X of
Blender's space (+X of the cube maps). Godot's PanoramaSkyMaterial wants it turned 180 degrees
(sky_rotation y = PI, as the addon's skies have it); Unity's Skybox/Panoramic takes it as it is.

Godot 4.3 and later
-------------------
Copy addons/low_poly_skies/ into your project's addons/ folder. A sky is a scene,
skies/<sky>.tscn: drop it into your scene and it brings its WorldEnvironment (the panorama, the
ambient light taken from it, an aerial fog that fades the distance into the sky) and its sun or
moon, a DirectionalLight3D shining from the sky's light. Or put skies/<sky>.tres, the Environment
alone, on a WorldEnvironment of your own and set your light from skies.json.

Each prop is a scene in props/: drag it in. A cloud is a few metres to tens of metres across:
scale it up and set it far off for a sky. The clouds have an AnimationPlayer with "drift", the
sun "shine", the star "twinkle". The lit props (sun, moon, star, lightning, rainbow) glow through
the material's emission.

demo/skies.tscn shows every sky over the meadow (left and right to change it, drag to look round,
P for the props); demo/gallery.tscn shows every prop (drag to turn, arrows to browse, A for all
of them). Low Poly Skies uses the same addon folder: it installs over this one.

Other engines and apps
----------------------
Unity: a panorama on a Skybox/Panoramic material (Mapping Latitude Longitude Layout, Image Type
360 Degrees), or the cube map's faces on Skybox/6 Sided; set it in Lighting > Environment. Unreal:
a panorama on a sky sphere's material, or the cube map imported as a Texture Cube. Use fbx/, glb/
or obj/ with textures/atlas.png, filtered, with mipmaps, multiplied by the vertex colours (the
baked occlusion) in your material, textures/atlas_glow.png as its emission.

License: CC BY 4.0, see LICENSE.txt for the credit line. Made by heyheythere:
https://heyheythere.itch.io
